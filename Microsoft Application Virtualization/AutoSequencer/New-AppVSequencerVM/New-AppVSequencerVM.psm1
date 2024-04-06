function findEligibleVirtualSwitch
{
    $switches = Get-VMSwitch
    if ($switches.Count -eq 1)
    {
        $vs = $switches[0]
        if (($vs.SwitchType -eq "External") -Or ($vs.SwitchType -eq "Internal"))
        {
            $vsName = $vs.Name
            Write-host "Select $vsName as the virtual switch for the VM" -BackgroundColor DarkGray
            return $vsName
        }
    }

    Write-host "Please specify an Internal or External virtual switch" -BackgroundColor Red
    return
}

function GetVhdArchitecture($VhdPath)
{
    $local:DismResult = dism /get-imageinfo /imagefile:$VhdPath /index:1

    $local:checkError = $local:DismResult | findstr /i "Error"
    if ($local:checkError)
    {
        Write-Host "Failed to get architecture from VHD: $VhdPath" -BackgroundColor Red
        Write-Host "Error: $local:DismResult" -BackgroundColor Red
        onCmdletStop
    }

    $local:architecture = $local:DismResult | findstr /i "Architecture" | findstr /i "x86"
    if ($local:architecture)
    {
        return ("x86")
    }
    
    $local:architecture = $local:DismResult | findstr /i "Architecture" | findstr /i "x64"
    if ($local:architecture)
    {
        return ("amd64")
    }
    
    Write-Host "Get unknown architecture: $local:architecture, from VHD: $VhdPath" -BackgroundColor Red
    onCmdletStop
}

function handleDismErrorAndStop($mountPoint)
{
    $local:DismResult = dism /Remount-Image /MountDir:"$mountPoint"
    $local:checkError = $local:DismResult | findstr /i "Error"

    if ($local:checkError)
    {
        Write-Host "Failed to cleanup remount" -BackgroundColor Red
        Write-Host $local:DismResult -BackgroundColor Red
        onCmdletStop
    }

    $local:DismResult = Dism /Unmount-Image /MountDir:"$mountPoint" /Discard
    $local:checkError = $local:DismResult | findstr /i "Error"

    if ($local:checkError)
    {
        Write-Host "Failed to cleanup unmount" -BackgroundColor Red
        Write-Host $local:DismResult -BackgroundColor Red
    }
    onCmdletStop
}

function GenerateComputerName($VmName)
{
    # Unattend xml has a limitation on computer name length to 15
    $local:MaxComputerNameLength  = 15
    $local:VmComputerName = $VmName
    if ($local:VmComputerName.length -gt $local:MaxComputerNameLength )
    {
        # In case there could be duplicate VM host name, using first half char from VmName as identity, plus second half from middle of ticks
        # Note, we take the middle part of ticks because its far left part is too big and will be a constant in relative long time, while the
        # far right part is too small and keep changing very fast. The middle part has we expected change (roughly in milliseconds) but keep
        # in order in a relative long time.
        $local:firstHalf = [int]($local:MaxComputerNameLength / 2)
        $local:appendixTicks = [System.DateTime]::Now.Ticks.ToString().SubString(4, ($local:MaxComputerNameLength - $local:firstHalf))
        $local:VmComputerName = $local:VmComputerName.SubString(0, $local:firstHalf) + $local:appendixTicks
    }
    Write-Host
    Write-Host "The VM computer will be created with ComputerName: $local:VmComputerName"
    Write-Host
    return ($local:VmComputerName)
}

function SetupUnattendXml($VmName, $ComputerName, $VhdPath)
{
    #prepare replacements
    $local:Replacements:ArchitectureReplacement = GetVhdArchitecture($VhdPath)
    $local:Replacements:AppVSequencerVmComputerName = $ComputerName
    $local:Replacements:GeneratedPasswordReplacement = GenerateRandomPassword
    $local:Replacements:PlainTestReplacement = "true"
    $local:Replacements:AppVSequencerUser = "AppVSequencerUser"
    
    #The unattend template file should be located in the same directory as this script
    $local:UnattendXml:TemplateFileLocation = $Script:AutoSequencingRoot + "\Unattend_Sequencer_User_Setup_Template.xml"
    $local:rootDataFolder = GetAutoSeqRootDataFolder
    $local:UnattendXml:MountRoot = $local:rootDataFolder + "\MountSequencerVhd"

    if (Test-Path "$local:UnattendXml:MountRoot")
    {
        Remove-Item "$local:UnattendXml:MountRoot" -Recurse | out-null
    }

    $local:DismResult = New-Item "$local:UnattendXml:MountRoot" -Type Directory -Force
    if (!$local:DismResult)
    {
        Write-Host "Failed to create directory: $local:UnattendXml:MountRoot" -BackgroundColor Red
        onCmdletStop
    }

    $local:DismResult = Dism /Mount-Image /ImageFile:"$VhdPath" /Index:1 /MountDir:"$local:UnattendXml:MountRoot"
    $local:checkError = $local:DismResult | findstr /i "Error"
    if ($local:checkError)
    {
        Write-Host "Failed to mount image: $VhdPath" -BackgroundColor Red
        Write-Host $local:DismResult -BackgroundColor Red
        handleDismErrorAndStop $local:UnattendXml:MountRoot
    }

    $local:UnattendXml:TargetDirectory = $local:UnattendXml:MountRoot + "\Windows\Panther"
    $local:UnattendXml:TargetFilePath = $local:UnattendXml:TargetDirectory + "\Unattend.xml"

    $local:DismResult = New-Item "$local:UnattendXml:TargetDirectory" -Type Directory -Force

    if ($local:DismResult)
    {
        $local:UnattendXml:Content = Get-Content $local:UnattendXml:TemplateFileLocation
        
        $local:UnattendXml:Content = $local:UnattendXml:Content.Replace('[{ArchitectureReplacement}]', $local:Replacements:ArchitectureReplacement)
        $local:UnattendXml:Content = $local:UnattendXml:Content.Replace('[{AppVSequencerVmComputerName}]', $local:Replacements:AppVSequencerVmComputerName)

        $local:UnattendXml:XmlSanitizedPassword = [Security.SecurityElement]::Escape($local:Replacements:GeneratedPasswordReplacement)
        $local:UnattendXml:Content = $local:UnattendXml:Content.Replace('[{GeneratedPasswordReplacement}]', $local:UnattendXml:XmlSanitizedPassword)
        $local:UnattendXml:Content = $local:UnattendXml:Content.Replace('[{PlainTestReplacement}]', $local:Replacements:PlainTestReplacement)
        $local:UnattendXml:Content = $local:UnattendXml:Content.Replace('[{AppVSequencerUser}]', $local:Replacements:AppVSequencerUser)

        $local:UnattendXml:Content | Set-Content $local:UnattendXml:TargetFilePath

        if ($Script:AUTOSEQ_DEBUG)
        {
            $local:UnattendXml:DebugFilePath = $local:rootDataFolder + "\" + $VmName + "_Unattend_debug.xml"
            $local:UnattendXml:Content | Set-Content $local:UnattendXml:DebugFilePath
        }
    }

    $local:DismResult = Dism /Unmount-Image /MountDir:"$local:UnattendXml:MountRoot" /Commit
    $local:checkError = $local:DismResult | findstr /i "Error"

    if ($local:checkError)
    {
        Write-Host "Error in unmounting $VhdPath. Exiting.." -BackgroundColor Red
        Write-Host $local:DismResult -BackgroundColor Red
        handleDismErrorAndStop $local:UnattendXml:MountRoot
    }
    
    #build credential for return
    $local:Replacements:securePassword = ConvertTo-SecureString -string "$local:Replacements:GeneratedPasswordReplacement" -AsPlainText -Force
    $local:Replacements:credAppVSequencerUser = New-Object system.management.automation.pscredential $local:Replacements:AppVSequencerUser, $local:Replacements:securePassword

    return ($local:Replacements:credAppVSequencerUser)
}

function enableRDP
{
    set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
}

function New-AppVSequencerVM
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName="VHD")]
        [Parameter(Mandatory = $true, ParameterSetName="VM")]
        [ValidateNotNullOrEmpty()]
        [string]$VMName,
        [Parameter(Mandatory = $true, ParameterSetName="VM")]
        [ValidateNotNullOrEmpty()]
        [string]$VMComputerName,
        [Parameter(Mandatory = $false, ParameterSetName="VM")]
        [ValidateNotNullOrEmpty()]
        [string]$VMCheckpoint,
        [Parameter(Mandatory = $true, ParameterSetName="VHD")]
        [Parameter(Mandatory = $true, ParameterSetName="VM")]
        [ValidateNotNullOrEmpty()]
        [string]$ADKPath,
        [Parameter(Mandatory = $true, ParameterSetName="VHD")]
        [ValidateNotNullOrEmpty()]
        [string]$VHDPath,
        [Parameter(Mandatory = $false, ParameterSetName="VHD")]
        [ValidateRange(0,[int64]::MaxValue)]
        [Int64]$VMMemory,
        [Parameter(Mandatory = $false, ParameterSetName="VHD")]
        [ValidateNotNullOrEmpty()]
        [string]$VMSwitch,
        [Parameter(Mandatory = $false, ParameterSetName="VHD")]
        [ValidateRange(1,64)]
        [int]$CPUCount,
        [ValidateRange(1,[int64]::MaxValue)]
        [Int64]$SessionSetupTimeout,
        [switch]$UseADKWebInstaller,
        [switch]$UseDynamicMemory
    )

    process {
        $Script:AUTOSEQ_DEBUG = $false

        $Script:AutoSequencingRoot = "$PSScriptRoot\.."

        Import-module "$Script:AutoSequencingRoot\AutoSequencingUtils.psm1" -Force
        Import-module "$Script:AutoSequencingRoot\AutoSequencingTelemetry.psm1" -Force

        onCmdletStart $MyInvocation.MyCommand

        $telemetryProviderLoaded = LoadAutoSequencingTelemetryProvider($Script:AutoSequencingRoot)
        if ($telemetryProviderLoaded -eq $false)
        {
            Write-host "Failed to initialize Auto-Sequencer telemetry provider" -BackgroundColor Red
            onCmdletStop
        }

        $telemetryId = New-Guid
        LogNewAppVSequencerVMStart -TelemetryId $telemetryId -VMMemory $VMMemory -CPUCount $CPUCount -SessionSetupTimeout $SessionSetupTimeout -UseADKWebInstaller $UseADKWebInstaller

        $reportFilePath = createReportFile $MyInvocation.MyCommand

        $DEFAULT_MEMORY_SIZE = 1024MB
        $VM_STATE_RUNNING = 2

        $VM_VIRTUAL_CPU_COUNT_MAX = 64

        if (!(checkHyperV))
        {
            LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message "Check Hyper-V failed"
            onCmdletStop
        }

        $vm = get-vm -name $VMName -erroraction ignore
        
        $local:cred = $null

        if ($PSCmdlet.ParameterSetName -eq "VM")
        {
            if (!$vm)
            {
                $invalidVMError = "Invalid VM name $VMName"
                LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message $invalidVMError
                Write-host $invalidVMError -BackgroundColor Red
                onCmdletStop
            }

            # If a VM Checkpoint was specified then apply that now
            if ($VMCheckpoint)
            {
                # Check if a snapshot by name $VMCheckpoint-sequencer-base already exist
                $sequencerBaseSnapshotName = getSequencerBaseSnapshotName($VMCheckpoint)
                $snapshot = Get-VMSnapshot -VMName $VMName -Name $sequencerBaseSnapshotName -ErrorAction SilentlyContinue
                if ($snapshot)
                {
                    Write-host "A checkpoint with the name $sequencerBaseSnapshotName already exists." -BackgroundColor Red
                    LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message "Invalid VM Checkpoint given"
                    onCmdletStop
                }

                Write-host "Will restore the VM $VMName to Checkpoint $VMCheckpoint"
                Restore-VMSnapshot -VMName $VMName -Name $VMCheckpoint -Confir:$false
                if ($? -eq $false)
                {
                    LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message "Restore-VMSnapshot failed"
                    onCmdletStop
                }
            }

            if ($vm.state -ne $VM_STATE_RUNNING)
            {
                start-vm $vm
            }

            #best effort to see if we already have user credential for the machine.
            $local:cred = RetrieveUserCredential $VMName

            if (!$SessionSetupTimeout)
            {
                $SessionSetupTimeout = getDefaultShortTimeout
            }

            $local:vmSession = GetVmSession $VMName $VMComputerName ([REF]$local:cred) $true $SessionSetupTimeout $reportFilePath
            if (!$local:vmSession)
            {
                $getVMSessionError = "Failed to get VM session"
                LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message $getVMSessionError
                Write-host $getVMSessionError -BackgroundColor Red
                onCmdletStop
            }

            # enable remote desktop for VM
            $ret = Invoke-Command -session $local:vmSession -ScriptBlock ${function:enableRDP}

            StoreUserCredential $VMName $local:cred $VMComputerName

            if (!(provisionVM $local:vmSession $ADKPath $UseADKWebInstaller))
            {
                LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message "Failed to provision VM for sequencing"
                onCmdletStop
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "VHD")
        {
            #clean up old VM

            if ($vm)
            {
                $removeVM = Read-host -prompt "$VMName already exists. Remove? (Y/N)"
                if ($removeVM -ne "Y")
                {
                    LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message "User chose not to remove the existing VM"
                    onCmdletStop
                }
                stop-vm $vm -force
                remove-vm $vm -force
            }

            if (!$VMMemory)
            {
                # sequencer minimum requirement
                $VMMemory = $DEFAULT_MEMORY_SIZE
            }
            else
            {
                $totalMemory = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory
                if ($VMMemory -gt $totalMemory)
                {
                    $invalidMemoryError = "Invalid memory value: $VMMemory. Please specify a value less than $totalMemory"
                    LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message $invalidMemoryError
                    Write-host $invalidMemoryError -BackgroundColor Red
                    onCmdletStop
                }
            }

            if (!$VMSwitch)
            {
                $VMSwitch = findEligibleVirtualSwitch
                if (!$VMSwitch)
                {
                    LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message "Failed to find eligible Virtual Switch"
                    onCmdletStop
                }
            }

            #In clean VHD scenario, we always regenerate the password.
            $local:VmComputerName = GenerateComputerName($VMName)
            $local:cred = SetupUnattendXml $VMName $local:VmComputerName $VHDPath

            # we need to store the user credential once it is generated
            StoreUserCredential $VMName $local:cred $local:VmComputerName

            $vm = New-VM -Name $VMName -MemoryStartupBytes $VMMemory -VHDPath $VHDPath -SwitchName $VMSwitch

            if (!$vm)
            {
                $errorCreatingVM = "Failed to create VM: $VMName"
                LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message $errorCreatingVM
                Write-host $errorCreatingVM -BackgroundColor Red
                onCmdletStop
            }

            if (!$CPUCount)
            {
                $cpuInfo = Get-WmiObject -class win32_processor
                if (!$cpuInfo)
                {
                    $errorCpuInfo = "Failed to get CPU information"
                    LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message $errorCpuInfo
                    Write-host $errorCpuInfo -BackgroundColor Red
                    onCmdletStop
                }

                $CPUCount = $cpuInfo.NumberOfCores
                if ($CPUCount -gt $VM_VIRTUAL_CPU_COUNT_MAX)
                {
                    $CPUCount = $VM_VIRTUAL_CPU_COUNT_MAX
                }

                if ($CPUCount -le 0)
                {
                    $CPUCount = 1
                }
            }

            writeToReport $reportFilePath "Setting CPU count to $CPUCount"
            Set-VMProcessor $VMName -Count $CPUCount

            # Setting dynamic memory to $true could cause unpredictable VM performance due to varying memory size
            # Recommend disabling dynamic memory on the VM and select VM memory that is possible with the available memory 
            # on the host machine
            if (!$UseDynamicMemory)
            {
                $UseDynamicMemory = $false
            }

            if ($UseDynamicMemory)
            {
                writeToReport $reportFilePath "Will enable Dynamic Memory for the VM $VMName"
                Set-VMMemory $VMName -DynamicMemoryEnabled $true
            }
            else
            {
                writeToReport $reportFilePath "Will disable Dynamic Memory for the VM $VMName"
                Set-VMMemory $VMName -DynamicMemoryEnabled $false
            }

            Write-host "VM $VMName created and starting, please wait for few minutes for the first time machine boot up ..."

            start-vm $vm

            if (!$SessionSetupTimeout)
            {
                $SessionSetupTimeout = getDefaultLongTimeout
            }

            $local:vmSession = GetVmSession $VMName $local:VmComputerName ([REF]$local:cred) $false $SessionSetupTimeout $reportFilePath

            if (!$local:vmSession)
            {
                $failedGetVMSession = "Failed to get VM session"
                LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message $failedGetVMSession
                Write-host $failedGetVMSession -BackgroundColor Red
                onCmdletStop
            }

            if (!(provisionVM $local:vmSession $ADKPath $UseADKWebInstaller))
            {
                LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message "Failed to provision VM for sequencing"
                onCmdletStop
            }
        }
        else
        {
            $invalidParam = "Invalid Parameter Set. Exiting.."
            LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message $invalidParam
            Write-host $invalidParam -BackgroundColor Red
            onCmdletStop
        }

        # Create the sequencer base snapshot
        if (!(createSequencerBaseVMSnapshot $VMName $VMCheckpoint))
        {
            $vmSnapshotError = "Create Sequencer Base VM Snapshot failed for $VMName"
            LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message $vmSnapshotError
            Write-host $vmSnapshotError -BackgroundColor Red
            onCmdletStop
        }

        remove-pssession $local:vmSession
        RemoveHostFromTrustedHostsList($local:VmComputerName)

        $vmProvisioningComplete = "VM provisioning complete."
        LogNewAppVSequencerVMStatus -TelemetryId $telemetryId -Message $vmProvisioningComplete
        Write-host $vmProvisioningComplete -BackgroundColor DarkGreen

        onCmdletCompletion
    }
}

function Connect-AppVSequencerVM
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$VMName,
        [ValidateRange(1,[int64]::MaxValue)]
        [Int64]$SessionSetupTimeout = 3
    )

    process {
        Import-module "$PSScriptRoot\..\AutoSequencingUtils.psm1" -Force
        Import-module "$PSScriptRoot\..\AutoSequencingTelemetry.psm1" -Force

        onCmdletStart $MyInvocation.MyCommand

        $telemetryProviderLoaded = LoadAutoSequencingTelemetryProvider($Script:AutoSequencingRoot)
        if ($telemetryProviderLoaded -eq $false)
        {
            Write-host "Failed to initialize Auto-Sequencer telemetry provider" -BackgroundColor Red
            onCmdletStop
        }

        $telemetryId = New-Guid
        LogConnectAppVSequencerVMStart -TelemetryId $telemetryId -SessionSetupTimeout $SessionSetupTimeout

        $VM_STATE_RUNNING = 2

        $reportFilePath = createReportFile $MyInvocation.MyCommand

        $cred = RetrieveUserCredential $VMName
        if (!$cred)
        {
            $getCredError = "Failed to get credential for the VM $VMName"
            LogConnectAppVSequencerVMStatus -TelemetryId $telemetryId -Message $getCredError
            Write-host $getCredError -BackgroundColor Red
            return
        }

        $VmComputerName = RetrieveVmComputerName $VMName
        if (!$VmComputerName)
        {
            $getComputerNameError = "Failed to get computer name for the VM $VMName"
            LogConnectAppVSequencerVMStatus -TelemetryId $telemetryId -Message $getComputerNameError
            Write-host $getComputerNameError -BackgroundColor Red
            return
        }

        $vm = get-vm -name $VMName -ErrorAction SilentlyContinue
        if (!$vm)
        {
            $vmNotFoundError = "VM $VMName does not exist"
            LogConnectAppVSequencerVMStatus -TelemetryId $telemetryId -Message $vmNotFoundError
            Write-host $vmNotFoundError -BackgroundColor Red
            return
        }

        if ($vm.state -ne $VM_STATE_RUNNING)
        {
            start-vm -Name $VMName
        }

        $s = GetVmSession $VMName $VmComputerName ([REF]$cred) $true $SessionSetupTimeout $reportFilePath
        if (!$s)
        {
            $vmGetSessionError = "Failed to get VM session"
            LogConnectAppVSequencerVMStatus -TelemetryId $telemetryId -Message $vmGetSessionError
            Write-host $vmGetSessionError -BackgroundColor Red
            return
        }

        $dnsResult = dnsResolve $s
        if (!$dnsResult)
        {
            $dnsResolveError = "Failed to DNS resolve for VM"
            LogConnectAppVSequencerVMStatus -TelemetryId $telemetryId -Message $dnsResolveError
            Write-host $dnsResolveError -BackgroundColor Red
            return
        }

        $procMstsc = setupAndShowVM $dnsResult $cred
        if (!$procMstsc)
        {
            $remoteError = "Failed to launch remote desktop session"
            LogConnectAppVSequencerVMStatus -TelemetryId $telemetryId -Message $remoteError
            Write-host $remoteError -BackgroundColor Red
        }

        LogConnectAppVSequencerVMStatus -TelemetryId $telemetryId -Message "Connect-AppVSequencerVM completed successfully"

        RemoveHostFromTrustedHostsList($local:VmComputerName)

        onCmdletCompletion
    }
}

Export-ModuleMember -Function New-AppVSequencerVM
Export-ModuleMember -Function Connect-AppVSequencerVM

# SIG # Begin signature block
# MIImQAYJKoZIhvcNAQcCoIImMTCCJi0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDWE6EWxU1sBLSE
# jka4Eqyw4r0u2Hu9D47fajLL1PTWvKCCC3IwggT6MIID4qADAgECAhMzAAAFQ3U4
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
# Ap1qedIX09rBlI4HeyVxRKsGaubUxt8jmpZ1xTGCGiQwghogAgEBMIGVMH4xCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTACEzMAAAVDdTgsE3T5vSUAAAAABUMw
# DQYJYIZIAWUDBAIBBQCggcYwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKOEgW+n
# brTmvq5M4QO0S36MPL4Se7TQRG3LdH7IZwwrMFoGCisGAQQBgjcCAQwxTDBKoCSA
# IgBNAGkAYwByAG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3AHOhIoAgaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcNAQEBBQAEggEAQbJgGV3c
# dxwdu9Z0JZuDs0ORCmvcBotlX1RvN6RohQhScINDjtLzYFB28eW7R8DNtiOqQAM6
# rkr12y2Z2YBGy+rsDRHFaqPVBmeO9pFK6hEwjQBam1jrTBXwHCmShBV+UZ3I4mwg
# sKKG1dk0YDzQMYpx7spsXa9ksVRYKhBwxt7zskVe7vcnnaj2ULGTtWgm7LnQVL2h
# VDfLM5RByYUDEvfNMr5Rj4BD+wcGpRDpqbsfVmfSxGqjTsC47LjFMO5fHdXfJ+NM
# +KBeL6LgDw9diOVz1ULxZWaK02dRKxYcrqaKS/Ga2yv2TQ6VYGUgReYO3nIdkvTK
# pOOb5trWBWCvSaGCF5YwgheSBgorBgEEAYI3AwMBMYIXgjCCF34GCSqGSIb3DQEH
# AqCCF28wghdrAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsqhkiG9w0BCRABBKCC
# AUAEggE8MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCB/U7Om
# stDyy1RhPnNVgp9UqsQgWy+fm57qJkNOMHbEZAIGZfxoxBDIGBIyMDI0MDQwMTAz
# MzIxOC40OFowBIACAfSggdGkgc4wgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlv
# bnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo4OTAwLTA1RTAtRDk0NzElMCMG
# A1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCCEe0wggcgMIIFCKAD
# AgECAhMzAAAB7eFfy9X3pV1zAAEAAAHtMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTIzMTIwNjE4NDU0MVoXDTI1MDMwNTE4
# NDU0MVowgcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAj
# BgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5T
# aGllbGQgVFNTIEVTTjo4OTAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAKgwwmySuupqnJwvE8LUfvMPuDzw2lsRpDpKNxMhFvMJXJhA2zPxNovWmoVM
# QA8vVfuiMvj8RoRb5SM2pmz9rIzJbhgikU9k/bHgUExUJ12x4XaL5owyMMeLQtxN
# BnEzazeYUysJkBZJ8thdgMiKYUHPyPSgtYbLdWAuYFMozjEuq/sNlTPwHZKgCZsS
# 2nraeBKXSE6g3vdIXAT5jbhK8ZAxaHKSkb69cPByla/AN75OCestHsBNEVc3klLb
# p2bbLLpJgUxFicwTd0wcJD9RAhBA0LycuYi90qQChYQxe0mwYSjdCszZLZIG/g+k
# dHNG6TNO0/5QBx4bEz0nKvBRA/k4ISZbphyETJENLA/iFT1/sHQDKHXg/D28mjuN
# 7A2N4w8iSad7ItKLSu6/ajH/FEa1wn3IE0LkFpGS2PPuy09qiNH48MDZ+4G0KjzE
# qWS3neZRvsBj4JkceqEubvql0wXoEe/ZO/CVUF5BE3bZeNpVVHAKCOAmc17C3s96
# NyulSfSocuAur7UE3UPNi6RaROvvBPTOXSJev422pSRZI6dZF97w3bW0Hq6/dWRb
# ycV0KG1ttlnPbil4u0kRm42s3xd/09M8zNlcMkEjURyJH/3VBwahkWZVsVVvatQg
# CzTX5mR7C9uGYZUN59f2hkbj8riAZSxO9Nb6vUlkzFRPYzCpAgMBAAGjggFJMIIB
# RTAdBgNVHQ4EFgQUzhvw7PfeECoER8qUBl/Q0qHgIhkwHwYDVR0jBBgwFoAUn6cV
# XQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUy
# MFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQ
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQl
# MjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAW
# BgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcN
# AQELBQADggIBAJ3WArZF354YvR4eL6ITr+oNjyxtuw7h6Zqdynoo837GrlkBq2IF
# HiOZFGGb71WKTQWjQMtaL83bxsUjt1djDT2ne8KKluPLgSiJ+bQ253v/hTfSL37t
# G9btc5DevHfv5Tu+r2WTrJikYI2nSOUnXzz8K5E+Comd+rkR15p8fYCgbjqEpZN4
# HsO5dqwa3qykk56cZ51Kt7fgxZmp5MhDSto4i1mcW4YPLj7GgPWpHPZBb67aAIdo
# bwBCOFhQzi5OL23qS22PpztdqavbOta5x4OHPuwou20tMnvCzlisDYjxxOVswB/Y
# pbQZWMptgZ34tkZ24Qrv/t+zgZSQypznUWw10bWf7OBzvMe7agYZ4IGDizxlHRkX
# LHuOyCb2xIUIpDkKxsC+Wv/rQ12TlN4xHwmzaQ1SJy7YKpnTfzfdOy9OCTuIPUou
# B9LXocS+M3qbhUokqCMns4knNpu1LglCBScmshl/KiyTgPXytmeL2lTA3TdaBOZ3
# XRZPCJk67iDxSfqIpw8xj+IWpO7ie2TMVTEEGlsUbqTUIg1maiKsRaYK0beXJnYh
# 12aO0h59OQi8ZZvgnHPPuXab8TaQY6LEMkexqFlWbCyg2+HLmS7+KdT751cfPD6G
# W+pNIVPz2sgVWFyaxY8Mk81FJKkyGgnfdXZlr+WQpxuRQzRJtCBL2qx3MIIHcTCC
# BVmgAwIBAgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWlj
# cm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMw
# MTgyMjI1WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOThpkzntHIhC3mi
# y9ckeb0O1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+
# Slr+uDZnhUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3
# oAo4bo3t1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+
# tuhiJdxqD89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0
# hyTD4MmPfrVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLN
# ueKNiOSWrAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZ
# nkXftnIv231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n
# 6Jl8P0zbr17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC
# 4jMYctenIPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vc
# G9H9stQcxWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtF
# tvUeh17aj54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEE
# BQIDAQABMCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNV
# HQ4EFgQUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3
# TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkG
# CSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8E
# BTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRP
# ME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEww
# SgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMv
# TWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCd
# VX38Kq3hLB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQ
# dTltuw8x5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnu
# e99qb74py27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYo
# VSfQJL1AoL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlC
# GVJ1ijbCHcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZ
# lvSP9pEB9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/
# ZPkkvnNtyo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtq
# RRFHqfG3rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+
# y/g75LcVv7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgk
# NWcr4A245oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqK
# Oghif9lwY1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCA1AwggI4AgEBMIH5oYHR
# pIHOMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYD
# VQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hp
# ZWxkIFRTUyBFU046ODkwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAO4drIpMJpixjEmH6hZP
# Hq5U8XD5oIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJ
# KoZIhvcNAQELBQACBQDptBV2MCIYDzIwMjQwMzMxMTcwMTQyWhgPMjAyNDA0MDEx
# NzAxNDJaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAOm0FXYCAQAwCgIBAAICHNEC
# Af8wBwIBAAICE+EwCgIFAOm1ZvYCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYB
# BAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQsFAAOC
# AQEADfzAW7gi09vgAu+OqVHDS4ljbu0H0w7Z1wOaRcty+UwiEOsi74qzEnwKxAqO
# YXwhF4HhOVi8ganP9T3E90lRWiwnEFH70nPwVORGbD1L0hTvbX5fOMUhDjAMcnfb
# dpqnvK8m75XkxjquO6oLk2kCVY6jxmv11YiiDRGLblwJwRqzOQLMFllAtWklqMY3
# oh57M0zYu4lir1YRZfHxQYKg3KUjkFQi/v7Ynby2LVPyGyb82qq4lANFIdKIhELD
# Ux/9sH4yma6meaRQR+dlXTmsGFkW4sUERd2cM2Zsd/IzXqd1lqNa1EciGZOCz8lA
# fPURrJVNqrNrfXMosD+6QgGIIDGCBA0wggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwAhMzAAAB7eFfy9X3pV1zAAEAAAHtMA0GCWCGSAFlAwQC
# AQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkE
# MSIEIBB/e12soK87cnattCkEn8zVEO3PkQLhvLA7OMtthxDCMIH6BgsqhkiG9w0B
# CRACLzGB6jCB5zCB5DCBvQQgjS4NaDQIWx4rErcDXqXXCsjCuxIOtdnrFJ/QXjFs
# yjkwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAe3h
# X8vV96VdcwABAAAB7TAiBCDzcRk9CwJpc74DDyHPpDw+/gdfJRScxHp/avuR1s/8
# AzANBgkqhkiG9w0BAQsFAASCAgAJarwB0ISRnJXVWWK4HS/s3G7F1C6+stJne9Oz
# 0qYfOjsxDjWU+AYyClZqemXACRhCZ9VQ1l6bG5PCzeJzmEQ5wwzsKAJqnRluOOE5
# j3aYEfi7gy48ad6A9I1NbSZl38Yze3VxYn+K2LRac8vyiDrslrfRDRWzbPn1UvJr
# epul/YpTujrd5ulCPbhcnCS1I6UpLDJriF5eVCnYIp95ulfc/coGV/sxbVLYrquy
# cfHensWOYfe4Lci2OI7MHVwHkqM2t2UhNWz8T7yhs2EGxqeIQhkLa3nmjrT41Tlh
# ce4nVo6jcIFStdtQayUsmaXqq55CM0rOhMS8NarVky5SS4xmM+7e2tF5Dvq6TL5r
# v20GIfMP3qK11RHHduem3iHw4yBvQScpqayEms5RUWb+ng9psihhnejq7oSpRUjH
# OTHm1JBgufjfdZFT6F/EiPztk8oTlPlDe3MjwmroGndlQKAh8jfo8MJwbBs3jTPu
# +hzz1PMAZwr6gK0K35lIRRvG/yOt3SNwDq746VIRTbsvFc5Qk5WNrdbQ8ca8vkp3
# W4QVlbjRzghrPQoF/cCAt73+Sq3zbdebo8IulNPADFt5UzG+inKhQZrE5+5H0smL
# oCF19VYUGX21vXhA+A1+BzTaRmCT2ljNaVoJUqO8CmOgUCSNyMeRLQxXtAZY25n4
# pcXNgQ==
# SIG # End signature block
