$vmSequencerBaseSnapshot = "sequencer-base"

# folder in VM to place the installer
$VM_FOLDER_INSTALLER = "ProductInstaller"
# folder in VM to place the AppV package to update
$VM_FOLDER_UPDATE_PACKAGE = "PackageToUpdate"
# folder in VM to place the custom script to install
$VM_FOLDER_CUSTOM_SCRIPT = "CustomScript"
# folder in VM to place the sequenced product
$VM_FOLDER_PRODUCT = "SequencedPackage"

function getDefaultShortTimeout
{
    # Use function instead of variable here for local scoping
    return 30
}

function getDefaultLongTimeout
{
    # Use function instead of variable here for local scoping
    return 60
}

function GetAutoSeqRootDataFolder()
{
    return $env:programdata + "\Microsoft Application Virtualization\AutoSequencer\SequencerMachines"
}

function GetAutoSeqLogFileFolder()
{
    return $env:temp + "\AutoSequencer\Logs"
}

function checkHyperV
{
    $featureObj = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
    if (!$featureObj)
    {
        Write-host "Hyper-V feature not available on this host. Exiting.." -ForegroundColor DarkGray
        return $false
    }

    if ($featureObj.state -ne "Enabled")
    {
        Write-host "Hyper-V is not enabled on this host. Please enable the Hyper-V feature and then re-run this script." -ForegroundColor DarkGray
        return $false
    }
    return $true
}

function validateConfigXML($ConfigFileXml)
{
    $xsdReader = [System.Xml.XmlReader]::Create("$PSScriptRoot\config.xsd")
    [System.Xml.Schema.ValidationEventHandler]$xsdValidationHandler = {
        Write-Host $("XSD error: " + $_.Message) -BackgroundColor Red
        return $false
    }

    $schema = [System.Xml.Schema.XmlSchema]::Read($xsdReader, $xsdValidationHandler)
    $xsdReader.Close()

    $ConfigFileXml.Schemas.Add($schema) | out-null
    $script:configError = 0

    $ConfigFileXml.Validate({
        Write-Host $("Config XML error: " + $_.Message) -BackgroundColor Red
        $script:configError++
    })
    
    return (!$script:configError)
}

function getSequencerBaseSnapshotName($VMCheckpoint)
{
    if ($VMCheckpoint)
    {
        $sequencerBaseSnapshotName = $VMCheckpoint + "-" + $vmSequencerBaseSnapshot
    }
    else
    {
        $sequencerBaseSnapshotName = $vmSequencerBaseSnapshot
    }

    return $sequencerBaseSnapshotName
}

function createSequencerBaseVMSnapshot($VMName, $VMCheckpoint)
{
    $sequencerBaseSnapshotName = getSequencerBaseSnapshotName($VMCheckpoint)

    $snapshot = Get-VMSnapshot -VMName $VMName -Name $sequencerBaseSnapshotName -ErrorAction SilentlyContinue
    if (!$snapshot)
    {
        Write-host "Creating sequencer base snapshot $sequencerBaseSnapshotName for $VMName"
        Checkpoint-VM -Name $VMName -SnapshotName $sequencerBaseSnapshotName
    }

    return $?
}

function RollbackVM($VMName, $VMCheckpoint)
{
    $sequencerBaseSnapshotName = getSequencerBaseSnapshotName($VMCheckpoint)
     
    $snapshot = Get-VMSnapshot -VMName $VMName -Name $sequencerBaseSnapshotName -ErrorAction SilentlyContinue
    if (!$snapshot)
    {
        Write-host "Sequencer Base checkpoint $sequencerBaseSnapshotName does not exist" -BackgroundColor Red
        return $false
    }
    else
    {
        Write-Host "Applying checkpoint $sequencerBaseSnapshotName to VM.."
        Restore-VMSnapshot $snapshot -Confirm:$false
        return $true
    }

    return $false
}

function getCleanPSSession($VMName, $VMCheckpoint, [REF]$credRef, $reportFilePath)
{
    $vmRestoredToCheckpoint = RollbackVM $VMName $VMCheckpoint
    if (!$vmRestoredToCheckpoint)
    {
        Write-host "Failed to restore VM $VMName to given the checkpoint $VMCheckpoint" -BackgroundColor Red
        return $null
    }

    $VM_STATE_RUNNING = 2

    $vm = get-vm -name $VMName -ErrorAction SilentlyContinue
    if (!$vm)
    {
        Write-host "VM $VMName does not exist" -BackgroundColor Red
        return $null
    }

    if ($vm.state -ne $VM_STATE_RUNNING)
    {
        start-vm $vm
    }    

    $local:VmComputerName = RetrieveVmComputerName $VMName
    $local:vmSession = GetVmSession $VMName $local:VmComputerName $credRef $true (getDefaultShortTimeout) $reportFilePath
    
    return ($local:vmSession)
}

function onCmdletStart($componentName)
{
    $local:rootPath = GetAutoSeqRootDataFolder
    New-Item $local:rootPath -Type Directory -Force | out-null
    
    $local:logPath = GetAutoSeqLogFileFolder 
    New-Item $local:logPath -Type Directory -Force | out-null

    $local:date = Get-Date -Format MM-dd-yyyy-HH-mm-ss
    $local:logFileName = "$local:logPath\$componentName-$local:date.txt"
    Write-host "Log file: $local:logFileName"

    Start-Transcript -path $local:logFileName -force -noClobber -append | out-null
}

function onCmdletStop
{
    # Some fatal error occured in the cmdlet execution.
    # Flush the log file and terminate the cmdlet execution.
    stop-Transcript | out-null
    break
}

function onCmdletCompletion
{
    # Cmdlet execution completed successfully. 
    # Flush the log file.
    stop-Transcript | out-null
}

function validateADKVersion($session)
{
    $SEQUENCER_MAJOR_VERSION = 10
    $SEQUENCER_BUILD_VERSION = 14913
    $SEQUENCER_VERSION_COUNT = 4

    $versionObj = invoke-command -session $session { gwmi win32_product -filter "Name LIKE '%appman sequencer%'" | Select-Object version }
    if (!$versionObj)
    {
        Write-host "Failed to get Sequencer version from VM" -BackgroundColor Red
        return $false
    }

    $versionArray = $versionObj.version.split(".")
    if (!$versionArray -Or $versionArray.Length -lt $SEQUENCER_VERSION_COUNT)
    {
        Write-host "Failed to parse Sequencer version from VM" -BackgroundColor Red
        return $false
    }

    $majorVersion = $versionArray[0]
    $buildVersion = $versionArray[2]
    if (($majorVersion -lt $SEQUENCER_MAJOR_VERSION) -Or ($buildVersion -lt $SEQUENCER_BUILD_VERSION))
    {
        Write-host "Invalid Sequencer version: Major $majorVersion, Build $buildVersion. Must have Major >= $SEQUENCER_MAJOR_VERSION and Build >= $SEQUENCER_BUILD_VERSION" -BackgroundColor Red
        return $false
    }

    return $true
}

function checkPsSessionError($sessionError, $checkVmUserCredentialError)
{
    if ($checkVmUserCredentialError -And $sessionError)
    {
        #There are too many different format info on credential related errors. Just check if there is 
        #any 'credential' included in the error message as best effort
        $local:credentialRelated = $sessionError[0].Exception.Message | findstr /i "Credential"
        if ($local:credentialRelated)
        {
            return $false
        }
    }
    return $true
}

function GenerateRandomPassword
{
    $local:Password:CharacterList = [char[]]( ([int][char]'a')..([int][char]'z') + ([int][char]'A')..([int][char]'Z') )
    $local:Password:CharacterLenght = Get-Random -Minimum 6 -Maximum 20
    $local:Password:NumberList = 0..9
    $local:Password:NumberLenght = Get-Random -Minimum 1 -Maximum 5
    $local:Password:Symbols = "!@#%^&*()".ToCharArray()
    $local:Password:SymbolsLenght = Get-Random -Minimum 1 -Maximum 5
  
    $local:Password:parts = ($local:Password:CharacterList | get-random -count $local:Password:CharacterLenght) + ($local:Password:NumberList | get-random -count $local:Password:NumberLenght) + ($local:Password:symbols | get-random -count $local:Password:SymbolsLenght)
    $local:OFS = '';
    $local:Password:Generated = [string]($local:Password:parts | sort { get-random -min 0 -max 100 })
    
    return $local:Password:Generated;
}

function GetVmSession($vmName, $vmComputerName, [REF]$vmUserCredRef, $checkVmUserCredentialError, $SessionSetupTimeout, $reportFilePath)
{
    $local:MAX_WAIT_MINUTES = $SessionSetupTimeout

    $local:MAX_WAIT_TIME = ([DateTime]::Now).AddMinutes($local:MAX_WAIT_MINUTES)
    $local:MAX_USERCRED_TRY = 3
    $local:userCredTried = 0
    $local:vmSession = $null
    $local:vmUserCred = $vmUserCredRef.Value

    if (!$vmComputerName)
    {
        Write-host "Failed to get the computer name for $vmName" -BackgroundColor Red
        return $null
    }

    Write-host -NoNewLine "Waiting for VM to finish starting up.."
    $vm = Get-VM $vmName
    if (!$vm)
    {
        Write-host "Failed to get the VM instance for $vmName" -BackgroundColor Red
        return $null
    }

    while (($vm.Heartbeat -ne "OkApplicationsHealthy") -and ($vm.Heartbeat -ne "OkApplicationsUnknown"))
    {       
        if ($local:MAX_WAIT_TIME -lt ([DateTime]::Now))
        {
            Write-host "."
            Write-host "Waited for $local:MAX_WAIT_MINUTES minutes and VM $vmName did not boot up successfully." -BackgroundColor Red
            return
        }

        start-sleep 20
    }
    Write-host "."

    $local:MAX_WAIT_TIME = ([DateTime]::Now).AddMinutes($local:MAX_WAIT_MINUTES)

    Write-host -NoNewLine "Waiting for VM session.."
    
    if (!$local:vmUserCred)
    {
        $local:vmUserCred = InputUserCredential $vmName
        $local:userCredTried = $local:userCredTried + 1
    }

    AddHostToTrustedHostsList($vmComputerName)
    while ($local:vmUserCred)
    {
        $local:vmSession = New-PSSession -ComputerName $vmComputerName -Credential $local:vmUserCred -ErrorAction SilentlyContinue -ErrorVariable sessionError 
        if ($local:vmSession)
        {
            break
        }

        # log every pssession error
        if ($sessionError)
        {
            if ($reportFilePath)
            {
                writeToReport $reportFilePath $sessionError
            }
            else
            {
                # if the report file is not given. print out everything on the screen
                Write-host $sessionError
            }
        }

        if (!(checkPsSessionError $sessionError $checkVmUserCredentialError))
        {
            if ($local:userCredTried -ge $local:MAX_USERCRED_TRY)
            {
                Write-host "Invalid user credential for the VM $vmName" -BackgroundColor Red
                return $null
            }
            
            $local:vmUserCred = InputUserCredential $vmName
            $local:userCredTried = $local:userCredTried + 1
        }
        else
        {
            if ($local:MAX_WAIT_TIME -lt ([DateTime]::Now))
            {
                Write-host "."
                Write-host "Waited for $local:MAX_WAIT_MINUTES minutes and did not create user session in $vmName successfully." -BackgroundColor Red
                return
            }
        
            Write-host -NoNewLine "."
            Start-Sleep 20
        }
    }
    Write-host "."
    
    if ($local:vmSession -And $local:userCredTried -ge 1)
    {
        #valid session created with user newly inputed password
        StoreUserCredential $VMName $vmUserCred
        $vmUserCredRef.Value = $local:vmUserCred
    }
    
    return ($local:vmSession)
}

function isHostnameExisting($existingNames, $newName)
{
    # existing and new names must both be non-null
    if (!$existingNames -or !$newName)
    {
        return $false
    }

    $nameArray = $existingNames.split(',').trim()
    if ($nameArray -contains $newName)
    {
        return $true
    }
    return $false
}

function removeNameFromExisting($existingNames, $newName)
{
    if (!$existingNames -or !$newName)
    {
        return
    }

    $nameArray = $existingNames.split(',').trim()
    $retArray = @()
    foreach ($curr in $nameArray)
    {
        # we need to do the comparison case-insensitively
        if($curr -ne $newName)
        {
            $retArray += $curr
        }
    }

    return ($retArray -join ',')
}

function AddHostToTrustedHostsList($vmComputerName)
{
    if (!$vmComputerName)
    {
        return
    }

    $local:currentTrustedHosts = (get-item wsman:localhost\client\trustedhosts).Value
    if ($local:currentTrustedHosts.Length -eq 0)
    {
        set-item wsman:localhost\client\trustedhosts -Value "$vmComputerName" -Force 
    }
    elseif ($local:currentTrustedHosts -ne "*")
    {
        if (!(isHostnameExisting $local:currentTrustedHosts $vmComputerName))
        {
            set-item wsman:localhost\client\trustedhosts -Value "$local:currentTrustedHosts,$vmComputerName" -Force 
        }
    }
}

function RemoveHostFromTrustedHostsList($vmComputerName)
{
    if (!$vmComputerName)
    {
        return
    }

    $local:currentTrustedHosts = (get-item wsman:localhost\client\trustedhosts).Value
    if ((isHostnameExisting $local:currentTrustedHosts $vmComputerName))
    {
        $local:currentTrustedHosts = removeNameFromExisting $local:currentTrustedHosts $vmComputerName
        set-item wsman:localhost\client\trustedhosts -Value "$local:currentTrustedHosts" -Force 
    }
}

function InputUserCredential($VmName)
{
    $local:cred = Get-Credential -Message "Please enter the credential for the VM $VmName"
    if (!$local:cred -or ($local:cred.UserName.Length -eq 0) -Or ($local:cred.Password.Length -eq 0))
    {
        #Give user one more chance
        $local:cred = Get-Credential -Message "Cannot use empty username or password. Please enter the credential for the VM $VmName"
        if (!$local:cred -or ($local:cred.UserName.Length -eq 0) -Or ($local:cred.Password.Length -eq 0))
        {
            return $null
        }
    }    
    return $local:cred
}

function StoreUserCredential($VmName, $VmUserCred, $VmComputerName)
{
    $local:rootPath = GetAutoSeqRootDataFolder  
    $local:credFilePath = $local:rootPath + "\$VmName"
    $VmUserCred.UserName | out-file "$local:credFilePath"
    $VmUserCred.Password | ConvertFrom-SecureString | Out-File "$local:credFilePath" -Append
    $VmComputerName | out-file "$local:credFilePath" -Append
}

function RetrieveUserCredential($VmName)
{
    $local:rootPath = GetAutoSeqRootDataFolder  
    $local:credFilePath = $local:rootPath + "\$VmName"
    if (Test-Path $local:credFilePath)
    {
        $local:userName = (Get-Content $local:credFilePath)[0]
        $local:password = (Get-Content $local:credFilePath)[1] | ConvertTo-SecureString
        $local:userCred = New-Object system.management.automation.pscredential $local:userName, $local:password
                
        return ($local:userCred)
    }
    
    return $null
}

function RetrieveVmComputerName($VmName)
{
    $local:rootPath = GetAutoSeqRootDataFolder  
    $local:credFilePath = $local:rootPath + "\$VmName"
    if (Test-Path $local:credFilePath)
    {
        $local:VmComputerName = (Get-Content $local:credFilePath)[2]
        return ($local:VmComputerName)
    }
    
    return $null
}

function dnsResolve($session)
{
    $vmHostname = invoke-command -session $session { hostname }
    if (!$vmHostname)
    {
        Write-host "Failed to get the hostname for VM" -BackgroundColor Red
        return
    }

    Write-host "DNS Resolving for $vmHostname"
    $dnsRecord = [System.Net.Dns]::GetHostEntry($vmHostname)
    if (!$dnsRecord)
    {
        Write-host "Failed to DNS resolve for $vmHostname" -BackgroundColor Red
        return
    }
    
    $ret = $dnsRecord.HostName
    Write-host "DNS Resolved $ret"
    return $ret
}

function setupAndShowVM($dnsResult, $cred)
{
    $username = $cred.UserName
    $pw = $cred.GetNetworkCredential().password

    $ret = Cmdkey /generic:$dnsResult /user:$username /pass:$pw
    $procMstsc = start-process mstsc /v:$dnsResult -PassThru
    if (!$procMstsc)
    {
        Write-host "Failed to create remote desktop process" -BackgroundColor Red
        return
    }
    return $procMstsc
}

function createReportFile($component, $reportFolder)
{
    if (!$reportFolder)
    {
        # if the folder is not given, use the temp folder
        $reportFolder = GetAutoSeqLogFileFolder
    }

    if (!(test-path $reportFolder))
    {
        $folderObj = new-item $reportFolder -type directory -force
    }

    $date = Get-Date -Format MM-dd-yyyy-HH-mm-ss
    $reportFileName = "$reportFolder\$component-report-$date.txt"

    Write-host "Report file: $reportFileName"

    $reportFile = New-Item $reportFileName -type file -force
    return $reportFileName
}

function writeToReport([string]$reportFile, $msg)
{
    Add-Content $reportFile $msg
}

function getCabFilesFromMsi([string]$msiFile, [string]$folder)
{
    $INVOKE_METHOD_ATTR = "InvokeMethod"
    $PROPERTY_INDEX_CAB_FILE = 4

    $installerCom = New-Object -com WindowsInstaller.Installer

    try {
        $msiDb = $installerCom.GetType().InvokeMember("OpenDatabase", $INVOKE_METHOD_ATTR, $null, $installerCom, @($msiFile, 0))

        $mediaQuery = "select * from Media"
        $dbView = $msiDb.GetType().InvokeMember("OpenView", $INVOKE_METHOD_ATTR, $null, $msiDb, ($mediaQuery))
        $ret = $dbView.GetType().InvokeMember("Execute", $INVOKE_METHOD_ATTR, $null, $dbView, $null)

        $files = @()

        $record = $dbView.GetType().InvokeMember("Fetch", $INVOKE_METHOD_ATTR, $null, $dbView, $null)
        while ($record) {
            # get the 4th property that contains the cab file name
            $cabFile = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, $PROPERTY_INDEX_CAB_FILE)

            $cabFile = $cabFile.trim()
            if ($cabFile)
            {
                $cabFile = $folder + $cabFile
                $files += $cabFile
            }

            $record = $dbView.GetType().InvokeMember("Fetch", $INVOKE_METHOD_ATTR, $null, $dbView, $null)
        }
    } catch {
        Write-host "Exception when parsing MSI files: $_ " -BackgroundColor Red
        $files = @()
    }

    return $files
}

function getADKFilesToCopy($ADKPath)
{
    $InstallersFolder = $ADKPath + "\Installers\"

    $KitsConfigInstallerFile = $InstallersFolder + "Kits Configuration Installer-x86_en-us.msi"
    $ToolkitDocFile = $InstallersFolder + "Toolkit Documentation-x86_en-us.msi"

    $SequencerX86MSI = $InstallersFolder + "Appman Sequencer on x86-x86_en-us.msi"
    $SequencerAmd64MSI = $InstallersFolder + "Appman Sequencer on amd64-x64_en-us.msi"

    $files = @($KitsConfigInstallerFile, $ToolkitDocFile, $SequencerX86MSI, $SequencerAmd64MSI)

    $cabFiles = getCabFilesFromMsi $KitsConfigInstallerFile $InstallersFolder
    if (!$cabFiles)
    {
        Write-host "No CAB files for Kit Config MSI" -BackgroundColor DarkGray
    }
    else
    {
        $files += $cabFiles
    }

    $cabFiles = getCabFilesFromMsi $ToolkitDocFile $InstallersFolder
    if (!$cabFiles)
    {
        Write-host "No CAB files for Tool Kit MSI" -BackgroundColor DarkGray
    }
    else
    {
        $files += $cabFiles
    }

    $cabFiles = getCabFilesFromMsi $SequencerX86MSI $InstallersFolder
    if (!$cabFiles)
    {
        Write-host "Failed to get CAB files for x86 Sequencer MSI" -BackgroundColor Red
        return
    }
    $files += $cabFiles

    $cabFiles = getCabFilesFromMsi $SequencerAmd64MSI $InstallersFolder
    if (!$cabFiles)
    {
        Write-host "Failed to get CAB files for amd64 Sequencer MSI" -BackgroundColor Red
        return
    }
    $files += $cabFiles
    
    foreach ($file in $files)
    {
        if (!(Test-Path $file))
        {
            Write-host "$file does not exist in the ADK folder" -BackgroundColor Red
            return
        }
    }

    return $files
}

function getVMPublicDocFolder($session)
{
    $vmSystemDrive = invoke-command -Session $session { $env:SystemDrive }
    if (!$vmSystemDrive)
    {
        Write-host "Failed to get system drive for VM" -BackgroundColor Red
        return
    }

    $publicDocFolder = "$vmSystemDrive\Users\Public\Documents"
    return $publicDocFolder
}

function printInstructionForGUISequencing($session)
{
    $publicDocFolder = getVMPublicDocFolder $session
    if (!$publicDocFolder)
    {
        return $false
    }

    $installerFolder = $publicDocFolder + "\" + $VM_FOLDER_INSTALLER
    $updatePkgFolder = $publicDocFolder + "\" + $VM_FOLDER_UPDATE_PACKAGE

    Write-host "The installer is at $installerFolder (For update, AppV package is at $updatePkgFolder )"
    return $true
}

function CopyFilesToVM($session, $appInstallerFolder, $updatePackage, $customScriptFolder)
{
    $publicDocFolder = getVMPublicDocFolder $session
    if (!$publicDocFolder)
    {
        return $false
    }

    copy-item -ToSession $session -path "$appInstallerFolder\*" -Destination "$publicDocFolder\$VM_FOLDER_INSTALLER\" -Recurse -Force

    if ($updatePackage)
    {
        copy-item -ToSession $session -path $updatePackage -Destination "$publicDocFolder\$VM_FOLDER_UPDATE_PACKAGE\" -Recurse -Force
    }

    if ($customScriptFolder)
    {
        copy-item -ToSession $session -path "$customScriptFolder\*" -Destination "$publicDocFolder\$VM_FOLDER_CUSTOM_SCRIPT\" -Recurse -Force
    }

    return $true
}

function copyAutoOutputFromVM($session, $hostOutputPath)
{
    $publicDocFolder = getVMPublicDocFolder $session
    if (!$publicDocFolder)
    {
        return $false
    }

    if (!(test-path $hostOutputPath))
    {
        new-item $hostOutputPath -type directory -force
    }

    copy-item -fromsession $session "$publicDocFolder\$VM_FOLDER_PRODUCT\*" $hostOutputPath -recurse -force
    return $true
}

function validateProvisioningStatus($session)
{
    $publicDocFullPath = getVMPublicDocFolder $session
    if (!$publicDocFullPath)
    {
        Write-host "Failed to validate the state of the VM" -BackgroundColor Red
        return $false
    }

    $ret = invoke-command -session $session -argumentlist "$publicDocFullPath\$VM_FOLDER_INSTALLER" { test-path $args[0] }
    $ret = $ret -And ( invoke-command -session $session -argumentlist "$publicDocFullPath\$VM_FOLDER_PRODUCT" { test-path $args[0] } )
    $ret = $ret -And ( invoke-command -session $session -argumentlist "$publicDocFullPath\$VM_FOLDER_UPDATE_PACKAGE" { test-path $args[0] } )
    $ret = $ret -And ( invoke-command -session $session -argumentlist "$publicDocFullPath\$VM_FOLDER_CUSTOM_SCRIPT" { test-path $args[0] } )
    $ret = $ret -And ( invoke-command -session $session -argumentlist "$publicDocFullPath\runner.ps1" { test-path $args[0] } )

    $ret = $ret -And (validateADKVersion $session)

    if (!$ret)
    {
        Write-host "Please use New-AppVSequencerVM to provision the VM before using it for sequencing" -BackgroundColor Red
        return $false
    }
    return $true
}

function provisionVM($session, $ADKPath, $UseADKWebInstaller)
{
    $SEQUENCER_RUNNER_FILE = "$PSScriptRoot\VmSetup\runner.ps1"

    $ADK_INSTALLER_NAME = "adksetup.exe"
    $ADK_SEQUENCER_INSTALL_OPTIONS = "/features OptionId.AppmanSequencer /q"

    if (!(Test-Path "$ADKPath\$ADK_INSTALLER_NAME"))
    {
        Write-host "Failed to find installer $ADK_INSTALLER_NAME in the given ADK folder" -BackgroundColor Red
        return $false
    }

    $publicDocFullPath = getVMPublicDocFolder $session
    if (!$publicDocFullPath)
    {
        return $false
    }

    $ret = invoke-command -session $session -argumentlist $publicDocFullPath, $VM_FOLDER_INSTALLER { new-item -Path $args[0] -Name $args[1] -type directory -force }
    $ret = invoke-command -session $session -argumentlist $publicDocFullPath, $VM_FOLDER_PRODUCT { new-item -Path $args[0] -Name $args[1] -type directory -force }
    $ret = invoke-command -session $session -argumentlist $publicDocFullPath, $VM_FOLDER_UPDATE_PACKAGE { new-item -Path $args[0] -Name $args[1] -type directory -force }
    $ret = invoke-command -session $session -argumentlist $publicDocFullPath, $VM_FOLDER_CUSTOM_SCRIPT { new-item -Path $args[0] -Name $args[1] -type directory -force }
    $ret = invoke-command -session $session -argumentlist $publicDocFullPath { new-item -Path $args[0] -Name "adk" -type directory -force }
    copy-item -ToSession $session -Path $SEQUENCER_RUNNER_FILE -Destination $publicDocFullPath -force

    if ($UseADKWebInstaller)
    {
        Write-host "ADK web installer requires an Internet connection on the VM"
        copy-item -ToSession $session -Path "$ADKPath\$ADK_INSTALLER_NAME" -Destination "$publicDocFullPath\adk\" -force
    }
    else
    {
        Write-host "Copying installer for Application Virtualization Sequencer from ADK to the VM.."

        $filesToCopy = getADKFilesToCopy $ADKPath
        if (!$filesToCopy)
        {
            Write-host "Failed to get installer for Application Virtualization Sequencer from ADK" -BackgroundColor Red
            return $false
        }

        $fileCount = $filesToCopy.Count
        $ProgressActivity = "Copying installation files.."

        $installersFolderExisting = invoke-command -session $session -argumentlist "$publicDocFullPath\adk\Installers" { Test-Path $args[0] }
        if (!$installersFolderExisting)
        {
            $ret = invoke-command -session $session -argumentlist "$publicDocFullPath\adk" { new-item -Path $args[0] -Name "Installers" -type directory -force }
        }

        for ($i = 0; $i -lt $fileCount; $i++)
        {
            $file = $filesToCopy[$i]
            Write-progress -Activity $ProgressActivity -Status "Copying $file" -PercentComplete ($i / ($fileCount + 1) * 100)
            copy-item -ToSession $session -Path $file -Destination "$publicDocFullPath\adk\Installers" -Recurse -force
        }

        Write-progress -Activity $ProgressActivity -Status "Copying $ADK_INSTALLER_NAME" -PercentComplete ($fileCount / ($fileCount + 1) * 100)
        copy-item -ToSession $session -Path "$ADKPath\$ADK_INSTALLER_NAME" -Destination "$publicDocFullPath\adk\" -force

        Write-progress -Activity $ProgressActivity -Status "Done" -Completed
    }

    Write-host "Installing Application Virtualization Sequencer on the VM.."

    invoke-command -session $session -argumentlist "$publicDocFullPath\adk\$ADK_INSTALLER_NAME", $ADK_SEQUENCER_INSTALL_OPTIONS { start-process -filepath $args[0] -argumentlist $args[1] -wait }
    
    $isValidADK = validateADKVersion $session
    if (!$isValidADK)
    {
        Write-host "Failed to install proper version of Application Virtualization Sequencer" -BackgroundColor Red
        return $false
    }

    # remove the ADK installer
    invoke-command -session $session -argumentlist "$publicDocFullPath\adk" { remove-item $args[0] -force -recurse -ErrorAction SilentlyContinue }

    return $true
}

# SIG # Begin signature block
# MIImQQYJKoZIhvcNAQcCoIImMjCCJi4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBdr2TLoxxMf0X6
# Qwtd/9OXWwcqlJnMrVmaHs/t3AtNraCCC3IwggT6MIID4qADAgECAhMzAAAFQ3U4
# LBN0+b0lAAAAAAVDMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTAwHhcNMjMwODA4MTgzNDI1WhcNMjQwODA3MTgzNDI1WjB/MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQDEyBNaWNy
# b3NvZnQgV2luZG93cyBLaXRzIFB1Ymxpc2hlcjCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBALHqvOR5b0s5sJRnmCJIvrx6O4Z3E/r4vrso4QNCyDpLOmTU
# +X2Grc9JoW5mR5jaFlUFN1oPL2h3ClAiwKe06jE9EFYytgNEoLOtdLaj2LML4YGU
# LpQ3uoXS5qHJVoXt4P0roS+VOgRcNRHTjcGRGeZO4k281xEsMFbYpSJwbomOnjnI
# TDNiVf3mNIDRJmm3hYWlLs3O/O7bLH5hbE2buEWNvmxvDeBJ9bKaBv8A5fl5jgYW
# EI5RK5KPhRjIn0j3BcpU5glQOFTa1U/qFeYqiq4dEI8JbjTeo+FooPuNOflNKkSG
# rpSeuEOQIXGbBJxuyrXP32/gFJMH2P3BL8MXLmkCAwEAAaOCAW4wggFqMB8GA1Ud
# JQQYMBYGCisGAQQBgjcKAxQGCCsGAQUFBwMDMB0GA1UdDgQWBBRW4VTuasbSNG07
# Z24sgDUV1cmqVTBFBgNVHREEPjA8pDowODEeMBwGA1UECxMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMRYwFAYDVQQFEw0yMjk5MDMrNTAxNDEzMB8GA1UdIwQYMBaAFOb8
# X3u7IgBY5HJOtfQhdCMy5u+sMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwu
# bWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY0NvZFNpZ1BDQV8yMDEw
# LTA3LTA2LmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljQ29kU2lnUENBXzIwMTAtMDct
# MDYuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggEBALACmXG6zirB
# t9gJ2/GOA3/VBc0AS53Zts52c8rnK9/lPteP9L7Tnp/vyjPDA1K0fmT9qlqNrUZj
# owKfIo/qIVtvxTIXRT7t4g9X4jm0wjDYmLWhJBn73qi4BPFbZHhimzgP/fhdpRKd
# n5BrlHnLLpnMS2ctr3nTGXl+9av9yvXr6emBNsFQRlFaYzeNHD6WZTQnPVat3gYP
# yk2sfYRuPiHbX2R/khv7jovT161P75+oVKQUjkkUPVqpcKEhV3AuHuCR5k/JXOfe
# fi6zBcrC6S2+xjZsNtjphnuuW1NwWD+To/fm2BzBvj5vDfrWet07mALM3tNpUEjN
# rEfWMBfXy10wggZwMIIEWKADAgECAgphDFJMAAAAAAADMA0GCSqGSIb3DQEBCwUA
# MIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQD
# EylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0x
# MDA3MDYyMDQwMTdaFw0yNTA3MDYyMDUwMTdaMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDpDmRQ
# eWe1xOP9CQBMnpSs91Zo6kTYz8VYT6mldnxtRbrTOZK0pB75+WWC5BfSj/1EnAjo
# ZZPOLFWEv30I4y4rqEErGLeiS25JTGsVB97R0sKJHnGUzbV/S7SvCNjMiNZrF5Q6
# k84mP+zm/jSYV9UdXUn2siou1YW7WT/4kLQrg3TKK7M7RuPwRknBF2ZUyRy9HcRV
# Yldy+Ge5JSA03l2mpZVeqyiAzdWynuUDtWPTshTIwciKJgpZfwfs/w7tgBI1TBKm
# vlJb9aba4IsLSHfWhUfVELnG6Krui2otBVxgxrQqW5wjHF9F4xoUHm83yxkzgGqJ
# TaNqZmN4k9Uwz5UfAgMBAAGjggHjMIIB3zAQBgkrBgEEAYI3FQEEAwIBADAdBgNV
# HQ4EFgQU5vxfe7siAFjkck619CF0IzLm76wwGQYJKwYBBAGCNxQCBAweCgBTAHUA
# YgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU
# 1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2Ny
# bC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIw
# MTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0w
# Ni0yMy5jcnQwgZ0GA1UdIASBlTCBkjCBjwYJKwYBBAGCNy4DMIGBMD0GCCsGAQUF
# BwIBFjFodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vUEtJL2RvY3MvQ1BTL2RlZmF1
# bHQuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAFAAbwBsAGkAYwB5
# AF8AUwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQAadO9X
# Tyl7xBaFeLhQ0yL8CZ2sgpf4NP8qLJeVEuXkv8+/k8jjNKnbgbjcHgC+0jVvr+V/
# eZV35QLU8evYzU4eG2GiwlojGvCMqGJRRWcI4z88HpP4MIUXyDlAptcOsyEp5aWh
# aYwik8x0mOehR0PyU6zADzBpf/7SJSBtb2HT3wfV2XIALGmGdj1R26Y5SMk3YW0H
# 3VMZy6fWYcK/4oOrD+Brm5XWfShRsIlKUaSabMi3H0oaDmmp19zBftFJcKq2rbty
# R2MX+qbWoqaG7KgQRJtjtrJpiQbHRoZ6GD/oxR0h1Xv5AiMtxUHLvx1MyBbvsZx/
# /CJLSYpuFeOmf3Zb0VN5kYWd1dLbPXM18zyuVLJSR2rAqhOV0o4R2plnXjKM+zeF
# 0dx1hZyHxlpXhcK/3Q2PjJst67TuzyfTtV5p+qQWBAGnJGdzz01Ptt4FVpd69+lS
# TfR3BU+FxtgL8Y7tQgnRDXbjI1Z4IiY2vsqxjG6qHeSF2kczYo+kyZEzX3EeQK+Y
# Zcki6EIhJYocLWDZN4lBiSoWD9dhPJRoYFLv1keZoIBA7hWBdz6c4FMYGlAdOJWb
# HmYzEyc5F3iHNs5Ow1+y9T1HU7bg5dsLYT0q15IszjdaPkBCMaQfEAjCVpy/JF1R
# Ap1qedIX09rBlI4HeyVxRKsGaubUxt8jmpZ1xTGCGiUwghohAgEBMIGVMH4xCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTACEzMAAAVDdTgsE3T5vSUAAAAABUMw
# DQYJYIZIAWUDBAIBBQCggcYwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAgY+RUy
# EtytWlD7UWsdtwuHgocuhWrwnHNu56c6LsffMFoGCisGAQQBgjcCAQwxTDBKoCSA
# IgBNAGkAYwByAG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggEAhD+G1TWA
# HqtJ+RIdPxw9Q088OJLlDKFrHJTqck/ryti5e9yTtksLscmKdgyLudIbnyH9zLln
# iOJAfKO7ZrAG534Ki6wDCRU5aEprAmZ7MSIE6HEvN8bcANqZytN/eLUKO12sxUuw
# gdL6FzODhsD1kqrtstvjWuKOdQTTHjQPbxkZOSVtrkUD6RO72pTW1k8TFpxFqR3U
# 1uhylFqyInASwRmIP4a71YR5lLreL/6M2sECAo0fDeg/oU3ML9OrSq2zCUI0evmX
# pE2WWEQzvTf1lgE4x1Pt9NpzyzPeHTCQcpWgi2vBSlZEzSCYbFDQR/f9Q2PbCjlT
# 2MrSYvnvw4epSKGCF5cwgheTBgorBgEEAYI3AwMBMYIXgzCCF38GCSqGSIb3DQEH
# AqCCF3AwghdsAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCC
# AUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCAvN2Cd
# HlpqymSiCdO8Yr4KruRcyouB/a4jqjtTZc1ckgIGZfxiikuyGBMyMDI0MDQwMTAz
# MzIxMy42NjVaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRp
# b25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTAwMC0wNUUwLUQ5NDcxJTAj
# BgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WgghHtMIIHIDCCBQig
# AwIBAgITMwAAAevgGGy1tu847QABAAAB6zANBgkqhkiG9w0BAQsFADB8MQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzEyMDYxODQ1MzRaFw0yNTAzMDUx
# ODQ1MzRaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUw
# IwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5u
# U2hpZWxkIFRTUyBFU046QTAwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQDBFWgh2lbgV3eJp01oqiaFBuYbNc7hSKmktvJ15NrB/DBboUow8WPOTPxb
# n7gcmIOGmwJkd+TyFx7KOnzrxnoB3huvv91fZuUugIsKTnAvg2BU/nfN7Zzn9Kk1
# mpuJ27S6xUDH4odFiX51ICcKl6EG4cxKgcDAinihT8xroJWVATL7p8bbfnwsc1pi
# hZmcvIuYGnb1TY9tnpdChWr9EARuCo3TiRGjM2Lp4piT2lD5hnd3VaGTepNqyakp
# kCGV0+cK8Vu/HkIZdvy+z5EL3ojTdFLL5vJ9IAogWf3XAu3d7SpFaaoeix0e1q55
# AD94ZwDP+izqLadsBR3tzjq2RfrCNL+Tmi/jalRto/J6bh4fPhHETnDC78T1yfXU
# QdGtmJ/utI/ANxi7HV8gAPzid9TYjMPbYqG8y5xz+gI/SFyj+aKtHHWmKzEXPttX
# zAcexJ1EH7wbuiVk3sErPK9MLg1Xb6hM5HIWA0jEAZhKEyd5hH2XMibzakbp2s2E
# JQWasQc4DMaF1EsQ1CzgClDYIYG6rUhudfI7k8L9KKCEufRbK5ldRYNAqddr/ySJ
# fuZv3PS3+vtD6X6q1H4UOmjDKdjoW3qs7JRMZmH9fkFkMzb6YSzr6eX1LoYm3PrO
# 1Jea43SYzlB3Tz84OvuVSV7NcidVtNqiZeWWpVjfavR+Jj/JOQIDAQABo4IBSTCC
# AUUwHQYDVR0OBBYEFHSeBazWVcxu4qT9O5jT2B+qAerhMB8GA1UdIwQYMBaAFJ+n
# FV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAl
# MjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKG
# UGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0
# JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAw
# FgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3
# DQEBCwUAA4ICAQCDdN8voPd8C+VWZP3+W87c/QbdbWK0sOt9Z4kEOWng7Kmh+WD2
# LnPJTJKIEaxniOct9wMgJ8yQywR8WHgDOvbwqdqsLUaM4NrertI6FI9rhjheaKxN
# NnBZzHZLDwlkL9vCEDe9Rc0dGSVd5Bg3CWknV3uvVau14F55ESTWIBNaQS9Cpo2O
# pz3cRgAYVfaLFGbArNcRvSWvSUbeI2IDqRxC4xBbRiNQ+1qHXDCPn0hGsXfL+ynD
# ZncCfszNrlgZT24XghvTzYMHcXioLVYo/2Hkyow6dI7uULJbKxLX8wHhsiwriXID
# CnjLVsG0E5bR82QgcseEhxbU2d1RVHcQtkUE7W9zxZqZ6/jPmaojZgXQO33XjxOH
# YYVa/BXcIuu8SMzPjjAAbujwTawpazLBv997LRB0ZObNckJYyQQpETSflN36jW+z
# 7R/nGyJqRZ3HtZ1lXW1f6zECAeP+9dy6nmcCrVcOqbQHX7Zr8WPcghHJAADlm5Ex
# Ph5xi1tNRk+i6F2a9SpTeQnZXP50w+JoTxISQq7vBij2nitAsSLaVeMqoPi+NXlT
# UNZ2NdtbFr6Iir9ZK9ufaz3FxfvDZo365vLOozmQOe/Z+pu4vY5zPmtNiVIcQnFy
# 7JZOiZVDI5bIdwQRai2quHKJ6ltUdsi3HjNnieuE72fT4eWhxtmnN5HYCDCCB3Ew
# ggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1p
# Y3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkz
# MDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5
# osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVri
# fkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFEx
# N6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S
# /rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3j
# tIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKy
# zbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX78
# 2Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjt
# p+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2
# AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb
# 3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXbGjfHCBUYP3ir
# Rbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUB
# BAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYD
# VR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGC
# N0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZ
# BgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/
# BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8E
# TzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9k
# dWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBM
# MEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRz
# L01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEA
# nVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx8
# 0HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ
# 7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2
# KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZ
# QhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa
# 2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RILLFORy3BFARx
# v2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRr
# akURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6T
# vsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4
# JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6
# ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNQMIICOAIBATCB+aGB
# 0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMG
# A1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNo
# aWVsZCBUU1MgRVNOOkEwMDAtMDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCABol1u1wwwYgUtUow
# MnqYvbul3qCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBCwUAAgUA6bQPrTAiGA8yMDI0MDMzMTE2MzcwMVoYDzIwMjQwNDAx
# MTYzNzAxWjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDptA+tAgEAMAoCAQACAguI
# AgH/MAcCAQACAhOeMAoCBQDptWEtAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisG
# AQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQAD
# ggEBAL35Zmnj2GOufnbWJ29Emxs+Pesu590sScyu2X0MWgS+vEgvcQACOAT7cuzo
# fCKA4NKoozhgFDcm8882HT6WH/EQy6q2k97LLdZN15wyCmWHlog4PJuhh3IcVxPx
# eeK/ZGhjl961kh29cL/qOFV62xY2Lyz64rCifnhs7I47aa250cYuiAZ8H5ckOJVT
# pbdg9BhB5702aZng0Xk2HSc+BcRpEMa8RzwYqTds8tKary+Y67ZUPN2Zs11iFTb/
# GAAOAXr8FEqRq0qcvScrs+nfeLU39zYjBvQIQtt/FKkVwJE7zTGcsUmIpAvJk6T5
# THZ9tTlyKAWj4o+6sE67CSPLvUkxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAevgGGy1tu847QABAAAB6zANBglghkgBZQME
# AgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJ
# BDEiBCBLfGnSIxV4eOZJZWcmAJwXUf3KQpKzo1AhgP1hRLZhHjCB+gYLKoZIhvcN
# AQkQAi8xgeowgecwgeQwgb0EIM63a75faQPhf8SBDTtk2DSUgIbdizXsz76h1Jdh
# LCz4MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHr
# 4BhstbbvOO0AAQAAAeswIgQgKTkAnsszbGwBQisipuPt/yOcSTYd312FD+bdzfiQ
# nV4wDQYJKoZIhvcNAQELBQAEggIAJFuEY5yxQg3CfHHErnwpD8ib2UgEofeOy934
# DsgCuvdaNoqL5qHRrGioswPoD4RAbF2mrM8RP/rR66Ss5rBUMqzEr7LEVhaN3bMl
# vb5EgLoAdLMxP0QkU3h6cGzD1MtJ6Vt9evpkLMO8+bkk9hWM9cLkTnIbsHpwKAaX
# MBa6+7RNjAsWtmM52uufP5sDJxoQSgZEsNGMnMWNPoAWZcbchUONyJnHx4H0XFjx
# 8cH3Q34CBs/VItVhWPtM2dbBbhwGTv2yK3nuva+NIdzBUA1HJY5nZSfGn7LXeBUL
# LI59TbpVmS3MUPbHbcx3NQ6FCL/ZkBRTRq+XldJCrsw8HDSHB4o6Cg7CuNmRBlKO
# Bg36lik9EJspu1SjFzHU/s2UQ+R2HATsqQJ0yQiUP+kA2VPCZSoIpgAPQsfUpzZs
# 9/jb0RvPa4QEB+Ep9OzN0wyN4v4NdcbUIZ3gKNRXi+YSb5+DlfGyKBjeibwGD14k
# qvbBGFMemLF+DAaUjfy6ENFRmPEWpo898VWC0Pt2I871dAc/xEqLP6FgA9/Sq4qp
# t+iAAODdNP2HV42Arh9TnnZ0CypUf3mdnD4TEc3mctwrSCNL0e+sQUSoDcJhi7Ra
# cOfu11e7SaNhebVkzA/61GLeye+g0CFRFPRc8n/5RDTYtRSxQjqUwi7K7NWAgQ4b
# 4GTY3CU=
# SIG # End signature block
