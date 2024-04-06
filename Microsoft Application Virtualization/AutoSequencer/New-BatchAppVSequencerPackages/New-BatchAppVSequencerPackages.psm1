function copyManualOutputFromVM($session, $hostOutputPath)
{
    $outputFolderVM = Read-Host -Prompt "When sequencing is done, enter output folder on the VM and continue (Type 'q' to skip)"
    while ($true)
    {
        if ($outputFolderVM -eq "q")
        {
            return
        }

        $isPathExisting = invoke-command -session $session -argumentlist "$outputFolderVM\*.appv" { Get-Item $args[0] -ErrorAction SilentlyContinue }
        if (!$isPathExisting)
        {
            $outputFolderVM = Read-Host -Prompt "Invalid output folder $outputFolderVM on the VM. Please enter a valid one (Type 'q' to skip)"
        }
        else
        {
            break
        }
    }

    if (!(test-path $hostOutputPath))
    {
        new-item $hostOutputPath -type directory -force
    }

    copy-item -fromsession $session $outputFolderVM $hostOutputPath -recurse -force
}

function WaitForTaskComplete($timeoutInMinutes)
{
    $TASK_NAME = "sequencer_task"
    $TASK_READY = 3
    $TASK_RUNNING = 4

    $POLL_INTERVAL = 20
    $TASK_START_POLL_INTERVAL = 5 

    if ($timeoutInMinutes -gt 0)
    {
        $timeElapsed = 0
        $timeoutInSecs = $timeoutInMinutes * 60
    }

    $task = Get-ScheduledTask $TASK_NAME
    Write-Host -NoNewLine "Waiting for sequencing task to start.."
    while ($task.state -eq $TASK_READY)
    {
        #still in ready state
        start-sleep -s $TASK_START_POLL_INTERVAL
        Write-Host -NoNewLine "."

        $task = Get-ScheduledTask $TASK_NAME
        if ($timeoutInSecs)
        {
            $timeElapsed = $timeElapsed + $TASK_START_POLL_INTERVAL
            if ($timeElapsed -ge $timeoutInSecs)
            {
                Write-Host "."
                Write-host "Timeout $timeoutInMinutes minutes triggered waiting for sequencing task to start" -BackgroundColor Red
                return $false
            }
        }
    }
    Write-Host "."

    if ($timeoutInMinutes -gt 0)
    {
        $timeElapsed = 0
    }

    if ($task.state -eq $TASK_RUNNING)
    {
        Write-Host -NoNewLine "Sequencing task is running.."

        while ($task.state -eq $TASK_RUNNING)
        {
            start-sleep -s $POLL_INTERVAL
            Write-Host -NoNewLine "."
            if ($timeoutInSecs)
            {
               $timeElapsed = $timeElapsed + $POLL_INTERVAL
               if ($timeElapsed -ge $timeoutInSecs)
               {
                    Write-Host "."
                    Write-host "Timeout $timeoutInMinutes minutes triggered for sequencing" -BackgroundColor Red
                    return $false
               }
            }

            $task = Get-ScheduledTask $TASK_NAME
        }
        Write-Host "."
    }

    Write-Host "Sequencing task has finished running"
    Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false
    return $true
}

function foundOutputError($appOutputFolder)
{
    $logFile = "$appOutputFolder\log.txt"
    if (!(Test-Path $logFile))
    {
        Write-host "Failed to get sequencing result from VM" -BackgroundColor Red
        return $true
    }

    $foundError = select-string "error|exception" $logFile -quiet
    if ($foundError)
    {
        Write-host "Error found in $logFile" -BackgroundColor Red
    }

    return $foundError
}

class CVMCheckPoint
{
    [String] $VMName
    CVMCheckPoint([String] $name)
    {
        $this.VMName = $name
    }

    [String] $OriginalCheckpointType
    [void]Initialize()
    {
        $local:vm = Get-VM $this.VMName
        if ($local:vm)
        {
            $this.OriginalCheckpointType = $local:vm.CheckpointType
            Set-VM -Name $this.VMName -CheckpointType Standard
        }
    }
   
    [void]Uninitialize()
    {
        if (!$this.OriginalCheckpointType)
        {
            return;
        }
        Set-VM -Name $this.VMName -CheckpointType $this.OriginalCheckpointType
    }
   
    [String] CreateCheckpoint($appName)
    {
        $date = Get-Date -Format MM-dd-yyyy-HH-mm-ss
        $checkpointName = "$appName-$date"
        Checkpoint-VM -Name $this.VMName -SnapshotName $checkpointName
        return $checkpointName
    }
}

function New-BatchAppVSequencerPackages
{
    [CmdletBinding()] 
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigFile,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VMName,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$VMCheckpoint,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    process {
        $Script:AutoSequencingRoot = "$PSScriptRoot\.."
        $WMI_LOGOFF_USER = 4

        Import-module "$Script:AutoSequencingRoot\AutoSequencingUtils.psm1" -Force
        Import-module "$Script:AutoSequencingRoot\AutoSequencingTelemetry.psm1" -Force

        onCmdletStart $MyInvocation.MyCommand
        
        $telemetryProviderLoaded = LoadAutoSequencingTelemetryProvider($Script:AutoSequencingRoot)
        if ($telemetryProviderLoaded -eq $false)
        {
            Write-host "Failed to initialize Auto-Sequencer telemetry" -BackgroundColor Red
            onCmdletStop
        }

        $telemetryId = New-Guid
        LogNewBatchAppVSequencerPackagesStart -TelemetryId $telemetryId

        # the path to "scheduler.ps1" to schedule the sequencing task
        $SCHEDULER_SCRIPT_FILE = "$Script:AutoSequencingRoot\VmSetup\scheduler.ps1"

        $local:cVmCheckPoint = New-Object CVMCheckPoint($VMName)

        try
        {
            if (!(checkHyperV))
            {
                LogNewBatchAppVSequencerPackagesStatus -TelemetryId $telemetryId -Message "Check Hyper-V failed"
                onCmdletStop
            }

            [xml]$ConfigFileXml = Get-Content $ConfigFile
            if (!$ConfigFileXml)
            {
                $loadConfigFileFailed = "Failed to load config XML file $ConfigFile"
                LogNewBatchAppVSequencerPackagesStatus -TelemetryId $telemetryId -Message $loadConfigFileFailed
                Write-host $loadConfigFileFailed -BackgroundColor Red
                onCmdletStop
            }

            $isValidXML = validateConfigXML $ConfigFileXml
            if (!$isValidXML)
            {
                LogNewBatchAppVSequencerPackagesStatus -TelemetryId $telemetryId -Message "Invalid Config Xml"
                onCmdletStop
            }

            $local:cred = RetrieveUserCredential $VMName
            $reportFilePath = createReportFile $MyInvocation.MyCommand $OutputPath

            $local:cVmCheckPoint.Initialize()

            $rootElement = $ConfigFileXml.Applications
            $appCount = $ConfigFileXml.selectnodes("/Applications/Application")
            $appCountMesg = "Number of applications in the batch " + $appCount.Count
            Write-host $appCountMesg
            LogNewBatchAppVSequencerPackagesStatus -TelemetryId $telemetryId -Message $appCountMesg
            foreach ($app in $rootElement.Application)
            {
                $appName = $app.AppName
                $enabled = $app.Enabled
                if ($enabled -eq "false")
                {
                    Write-host "Skipping $appName" -BackgroundColor DarkGray
                    writeToReport $reportFilePath "Skipping $appName"
                    continue
                }

                # Verify that "AppName" is specified if the installer is command line 
                if ($app.Cmdlet -eq "true")
                {
                    # Command Line based installer
                    if (($appName -eq $null) -or (($appName -eq "")))
                    {
                        $errorMessage = "App name must be specified in config xml for command line installer $app.Installer. Skipping entry"
                        Write-Host $errorMessage
                        writeToReport $reportFilePath $errorMessage
                        continue
                    }
                }

                Write-host "-- Start sequencing $appName  --"

                $s = getCleanPSSession $VMName $VMCheckpoint ([REF]$local:cred) $reportFilePath
                if (!$s)
                {
                    break
                }

                $isProvisioned = validateProvisioningStatus $s
                if (!$isProvisioned)
                {
                    break
                }

                Write-host "Copying installer to VM.."
                $installerFolder = $app.InstallerFolder
                $updatePackage = $app.Package
                $customScriptFolder = $app.CustomScriptFolder
                if (!(CopyFilesToVM $s $installerFolder $updatePackage $customScriptFolder))
                {
                    break
                }

                # before scheduling task, we want to make sure the user is logged off
                # since the task will only run when the user logs in. If the user is already logged off
                # we just ignore the exception being thrown
                Invoke-Command -Session $s -argumentlist $WMI_LOGOFF_USER { try { (gwmi win32_operatingsystem ).Win32Shutdown($args[0]) | out-null } catch {} }

                Write-host "Scheduling sequencing task.."
                $installer = $app.Installer
                $installerOptions = $app.InstallerOptions

                # fill in an empty install option if missing
                if (!$installerOptions)
                {
                    $installerOptions = ""
                }

                if ($updatePackage)
                {
                    $isUpdatePackage = $true
                }
                else
                {
                    $isUpdatePackage = $false
                }

                $isCmdlet = $app.Cmdlet
                if ($isCmdlet -eq "false")
                {
                    #Launch Sequencer GUI
                    if (!(printInstructionForGUISequencing $s))
                    {
                        continue
                    }
                    invoke-command -session $s -filepath $SCHEDULER_SCRIPT_FILE -argumentlist $false, $local:cred.UserName
                }
                else
                {
                    [int]$timeoutInMinutes = $app.TimeoutInMinutes
                    if (!$timeoutInMinutes)
                    {
                        $timeoutInMinutes = 0
                    }
                    invoke-command -session $s -filepath $SCHEDULER_SCRIPT_FILE -argumentlist $true, $local:cred.UserName, $appName, $installer, $installerOptions, $isUpdatePackage, $timeoutInMinutes
                }

                # always show the VM
                $dnsResult = dnsResolve $s
                if (!$dnsResult)
                {
                    $dnsResolveError = "Failed to DNS resolve for VM"
                    writeToReport $dnsResolveError $reportFilePath 
                    continue
                }

                $procMstsc = setupAndShowVM $dnsResult $local:cred
                if (!$procMstsc)
                {
                    $vmLaunchError = "Failed to launch VM"
                    LogNewBatchAppVSequencerPackagesStatus -TelemetryId $telemetryId -Message $vmLaunchError
                    writeToReport $vmLaunchError $reportFilePath 
                    continue
                }

                if ($isCmdlet -eq "false")
                {
                    copyManualOutputFromVM $s $OutputPath
                    writeToReport $reportFilePath "Done manual sequencing $appName"
                }
                else
                {
                    $ret = Invoke-Command -session $s -ScriptBlock ${function:WaitForTaskComplete} -argumentlist $timeoutInMinutes

                    # Always try and copy output from VM 
                    if (!(copyAutoOutputFromVM $s $OutputPath))
                    {
                        writeToReport $reportFilePath "Failed to copy output"
                    }

                    if ($ret)
                    {
                        if ((foundOutputError "$OutputPath\$appName"))
                        {
                            writeToReport $reportFilePath "Error found in sequencing $appName"
                        }
                        else
                        {
                            writeToReport $reportFilePath "Done sequencing $appName"
                        }
                    }
                    else
                    {
                        $local:checkpointName = $local:cVmCheckPoint.CreateCheckpoint($appName)
                        Write-Host "Failed to sequence $appName. VM checkpoint $local:checkpointName created for troubleshooting." -BackgroundColor Red
                        writeToReport $reportFilePath "Failed to sequence $appName. VM checkpoint $local:checkpointName created for troubleshooting"
                    }
                }
    
                if (!($procMstsc.HasExited))
                {
                    # close the VM window
                    stop-process -id $procMstsc.id
                }

                # clean up the key store
                $ret = cmdkey /delete:$dnsResult

                remove-pssession -session $s
                $local:VmComputerName = RetrieveVmComputerName $VMName
                RemoveHostFromTrustedHostsList($local:VmComputerName)

                $doneSequencing = "-- Done sequencing $appName --"
                LogNewBatchAppVSequencerPackagesStatus -TelemetryId $telemetryId -Message $doneSequencing
                Write-host $doneSequencing
            }

            $sequencingComplete = "Sequencing complete."
            LogNewBatchAppVSequencerPackagesStatus -TelemetryId $telemetryId -Message $sequencingComplete
            Write-host $sequencingComplete -BackgroundColor DarkGreen

            onCmdletCompletion
        }
        finally
        {
            $local:cVmCheckPoint.Uninitialize() 
        }
    }
}

Export-ModuleMember -Function New-BatchAppVSequencerPackages

# SIG # Begin signature block
# MIImUAYJKoZIhvcNAQcCoIImQTCCJj0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCO5NIbr8YJeioz
# JxFkemzoDbsJc6QiHB935/2+g4d43aCCC4EwggUJMIID8aADAgECAhMzAAAFQqa3
# Ynbi2cZgAAAAAAVCMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTAwHhcNMjMwODA4MTgzNDI0WhcNMjQwODA3MTgzNDI0WjB/MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQDEyBNaWNy
# b3NvZnQgV2luZG93cyBLaXRzIFB1Ymxpc2hlcjCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBAJwlmIwCpx3oCLCV7eScfHhd97uibO1jY3ZG5dqXeOSTEfIF
# T2q2cyi5iU1fAca//ykgNAMP3bHZ1ORJS2MXPJs5xWXm8vXsYSK/o3xchvj7Z+7j
# oSq9CAiQB60iXW60IEWQuctFLxiacHMlPfAV8UpF2Otqb4rFkFjeNAvfs8gR49bJ
# dKh8ptLiqM1Fq9rckFEw5U3kfmwMd6+pqsttkBk3lz6QxX010pVtx82vdjmtPrYN
# 9o9P85tRZ+WGEMPONtohDmv8l7fgFgs7HOvWuyPI480ePKgErtLtyTExi4ua7tNR
# DZoTM953wfIpHv8Twq/a8nAFJQtjCe2HNUTBHLcCAwEAAaOCAX0wggF5MB8GA1Ud
# JQQYMBYGCisGAQQBgjcKAxQGCCsGAQUFBwMDMB0GA1UdDgQWBBRVTqC7Vfgt5Vrd
# jboGEjRcKjkumDBUBgNVHREETTBLpEkwRzEtMCsGA1UECxMkTWljcm9zb2Z0IEly
# ZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMRYwFAYDVQQFEw0yMjk5MDMrNTAxNDM5
# MB8GA1UdIwQYMBaAFOb8X3u7IgBY5HJOtfQhdCMy5u+sMFYGA1UdHwRPME0wS6BJ
# oEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01p
# Y0NvZFNpZ1BDQV8yMDEwLTA3LTA2LmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYB
# BQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljQ29k
# U2lnUENBXzIwMTAtMDctMDYuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQEL
# BQADggEBADgHT3Vl70JHM/joVFH3xRAmLLIMBvkY8zoG08avpCaBoAKv8Wj8rbmn
# TXR3r5dvmxjZjBAxiSaohpNX84EA2FsMox0bvKxC23LFQ/LtHWNDYDX+ffAKNwud
# V6ltksbz5Vk7Qh6oONcIR9IzCvbqWzZQ/PbrmjSRskiTgxRxpufhnDu6Ylqs1Hd8
# YhCtOuOS8DSxPEKFYX06yekO+Bbg6AT9cTuRa3uMJ47h17mlfYKT3PnweYJJ0vxe
# D+I0MOqFF0rUutCcF/4JYYKRBUCgvVE5jf3ujK456uRskTYEs3IrIDf6wJ7hJY1e
# NNPpY8UWk117N5WxkkxJp3WNcNtFhnowggZwMIIEWKADAgECAgphDFJMAAAAAAAD
# MA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAxMDAeFw0xMDA3MDYyMDQwMTdaFw0yNTA3MDYyMDUwMTdaMH4xCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jv
# c29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTAwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDpDmRQeWe1xOP9CQBMnpSs91Zo6kTYz8VYT6mldnxtRbrTOZK0
# pB75+WWC5BfSj/1EnAjoZZPOLFWEv30I4y4rqEErGLeiS25JTGsVB97R0sKJHnGU
# zbV/S7SvCNjMiNZrF5Q6k84mP+zm/jSYV9UdXUn2siou1YW7WT/4kLQrg3TKK7M7
# RuPwRknBF2ZUyRy9HcRVYldy+Ge5JSA03l2mpZVeqyiAzdWynuUDtWPTshTIwciK
# JgpZfwfs/w7tgBI1TBKmvlJb9aba4IsLSHfWhUfVELnG6Krui2otBVxgxrQqW5wj
# HF9F4xoUHm83yxkzgGqJTaNqZmN4k9Uwz5UfAgMBAAGjggHjMIIB3zAQBgkrBgEE
# AYI3FQEEAwIBADAdBgNVHQ4EFgQU5vxfe7siAFjkck619CF0IzLm76wwGQYJKwYB
# BAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMB
# Af8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBL
# oEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMv
# TWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggr
# BgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNS
# b29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwgZ0GA1UdIASBlTCBkjCBjwYJKwYBBAGC
# Ny4DMIGBMD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vUEtJ
# L2RvY3MvQ1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEA
# bABfAFAAbwBsAGkAYwB5AF8AUwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3
# DQEBCwUAA4ICAQAadO9XTyl7xBaFeLhQ0yL8CZ2sgpf4NP8qLJeVEuXkv8+/k8jj
# NKnbgbjcHgC+0jVvr+V/eZV35QLU8evYzU4eG2GiwlojGvCMqGJRRWcI4z88HpP4
# MIUXyDlAptcOsyEp5aWhaYwik8x0mOehR0PyU6zADzBpf/7SJSBtb2HT3wfV2XIA
# LGmGdj1R26Y5SMk3YW0H3VMZy6fWYcK/4oOrD+Brm5XWfShRsIlKUaSabMi3H0oa
# Dmmp19zBftFJcKq2rbtyR2MX+qbWoqaG7KgQRJtjtrJpiQbHRoZ6GD/oxR0h1Xv5
# AiMtxUHLvx1MyBbvsZx//CJLSYpuFeOmf3Zb0VN5kYWd1dLbPXM18zyuVLJSR2rA
# qhOV0o4R2plnXjKM+zeF0dx1hZyHxlpXhcK/3Q2PjJst67TuzyfTtV5p+qQWBAGn
# JGdzz01Ptt4FVpd69+lSTfR3BU+FxtgL8Y7tQgnRDXbjI1Z4IiY2vsqxjG6qHeSF
# 2kczYo+kyZEzX3EeQK+YZcki6EIhJYocLWDZN4lBiSoWD9dhPJRoYFLv1keZoIBA
# 7hWBdz6c4FMYGlAdOJWbHmYzEyc5F3iHNs5Ow1+y9T1HU7bg5dsLYT0q15Iszjda
# PkBCMaQfEAjCVpy/JF1RAp1qedIX09rBlI4HeyVxRKsGaubUxt8jmpZ1xTGCGiUw
# ghohAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTACEzMAAAVC
# prdiduLZxmAAAAAABUIwDQYJYIZIAWUDBAIBBQCggcYwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZI
# hvcNAQkEMSIEIC6L93AzEckfBdTI2uhs8lhMKomW4b2Qpl753eThc2IpMFoGCisG
# AQQBgjcCAQwxTDBKoCSAIgBNAGkAYwByAG8AcwBvAGYAdAAgAFcAaQBuAGQAbwB3
# AHOhIoAgaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3dpbmRvd3MwDQYJKoZIhvcN
# AQEBBQAEggEAllplPTWbmp7KMrR1dWLGcREh/lKdxIS5NIpoDD6ep4je6m8f0pl4
# TohjoluErqAhxaazlwRQD0X5A1eSjEBLX1ltp+3QHI6rzXPK1WnLhPBCfS6wrZim
# 7zqIdGAKchzbAlfM2ll+FIDP+kwHIOYlV5fR61PfBLkEQnCuFvV2ML2LtBl760hp
# eD+G7zlVFO14ONnaFnQkTKYMoXDCld9atFH74GZeABHSfg3gkQtFAlWsArVhiUlZ
# cQ4MVtVjAxLexLTrLyQENsspFd8NmvR19KGdT2xVG9mQu/I6MT48JhhAGGCBzf+6
# FTjOLe9QaWROir8jZutdIU0ZOeJDN/nlN6GCF5cwgheTBgorBgEEAYI3AwMBMYIX
# gzCCF38GCSqGSIb3DQEHAqCCF3AwghdsAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFS
# BgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCG
# SAFlAwQCAQUABCCSnLclJANaQq2gGcVY+CMX3b3YrTwmxoY3s3qyKy0qAQIGZfxp
# 6f9gGBMyMDI0MDQwMTAzMzIxNy4zNDhaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQg
# QW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046Mzcw
# My0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZp
# Y2WgghHtMIIHIDCCBQigAwIBAgITMwAAAeqaJHLVWT9hYwABAAAB6jANBgkqhkiG
# 9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYw
# JAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzEyMDYx
# ODQ1MzBaFw0yNTAzMDUxODQ1MzBaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRp
# b25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MzcwMy0wNUUwLUQ5NDcxJTAj
# BgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQC1C1/xSD8gB9X7Ludoo2rWb2ksqaF65QtJkbQp
# msc6G4bg5MOv6WP/uJ4XOJvKX/c1t0ej4oWBqdGD6VbjXX4T0KfylTulrzKtgxnx
# Zh7q1uD0Dy/w5G0DJDPb6oxQrz6vMV2Z3y9ZxjfZqBnDfqGon/4VDHnZhdas22sv
# SC5GHywsQ2J90MM7L4ecY8TnLI85kXXTVESb09txL2tHMYrB+KHCy08ds36an7Ic
# OGfRmhHbFoPa5om9YGpVKS8xeT7EAwW7WbXL/lo5p9KRRIjAlsBBHD1TdGBucrGC
# 3TQXSTp9s7DjkvvNFuUa0BKsz6UiCLxJGQSZhd2iOJTEfJ1fxYk2nY6SCKsV+Vmt
# V5aiPzY/sWoFY542+zzrAPr4elrvr9uB6ci/Kci//EOERZEUTBPXME/ia+t8jrT2
# y3ug15MSCVuhOsNrmuZFwaRCrRED0yz4V9wlMTGHIJW55iNM3HPVJJ19vOSvrCP9
# lsEcEwWZIQ1FCyPOnkM1fs7880dahAa5UmPqMk5WEKxzDPVp081X5RQ6HGVUz6Zd
# gQ0jcT59EG+CKDPRD6mx8ovzIpS/r/wEHPKt5kOhYrjyQHXc9KHKTWfXpAVj1Syq
# t5X4nr+Mpeubv+N/PjQEPr0iYJDjSzJrqILhBs5pytb6vyR8HUVMp+mAA4rXjOw4
# 2vkHfQIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFCuBRSWiUebpF0BU1MTIcosFblle
# MB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBS
# oFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29m
# dCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRg
# MF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0
# MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/
# BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQAog61WXj9+/nxVbX3G37KgvyoNAnuu
# 2w3HoWZj3H0YCeQ3b9KSZThVThW4iFcHrKnhFMBbXJX4uQI53kOWSaWCaV3xCznp
# Rt3c4/gSn3dvO/1GP3MJkpJfgo56CgS9zLOiP31kfmpUdPqekZb4ivMR6LoPb5HN
# lq0WbBpzFbtsTjNrTyfqqcqAwc6r99Df2UQTqDa0vzwpA8CxiAg2KlbPyMwBOPcr
# 9hJT8sGpX/ZhLDh11dZcbUAzXHo1RJorSSftVa9hLWnzxGzEGafPUwLmoETihOGL
# qIQlCpvr94Hiak0Gq0wY6lduUQjk/lxZ4EzAw/cGMek8J3QdiNS8u9ujYh1B7NLr
# 6t3IglfScDV3bdVWet1itTUoKVRLIivRDwAT7dRH13Cq32j2JG5BYu/XitRE8cdz
# aJmDVBzYhlPl9QXvC+6qR8I6NIN/9914bTq/S4g6FF4f1dixUxE4qlfUPMixGr0F
# t4/S0P4fwmhs+WHRn62PB4j3zCHixKJCsRn9IR3ExBQKQdMi5auiqB6xQBADUf+F
# 7hSKZfbA8sFSFreLSqhvj+qUQF84NcxuaxpbJWVpsO18IL4Qbt45Cz/QMa7EmMGN
# n7a8MM3uTQOlQy0u6c/jq111i1JqMjayTceQZNMBMM5EMc5Dr5m3T4bDj9WTNLgP
# 8SFe3EqTaWVMOTCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJ
# KoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0
# eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25
# PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsH
# FPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTa
# mDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc
# 6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF
# 50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpG
# dc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOm
# TTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi
# 0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU
# 2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSF
# F5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCC
# AdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6C
# kTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1Ud
# IARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUE
# DDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8E
# BAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2U
# kFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5j
# b20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmww
# WgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkq
# hkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaT
# lz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYu
# nKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f
# 8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVC
# s/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzs
# kYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzH
# VG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+k
# KNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+
# CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAo
# GokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEz
# fbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKh
# ggNQMIICOAIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9u
# czEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjM3MDMtMDVFMC1EOTQ3MSUwIwYD
# VQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoD
# FQCJ2x7cQfjpRskJ8UGIctOCkmEkj6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6bQWYTAiGA8yMDI0MDMzMTE3
# MDUzN1oYDzIwMjQwNDAxMTcwNTM3WjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDp
# tBZhAgEAMAoCAQACAjMSAgH/MAcCAQACAhqpMAoCBQDptWfhAgEAMDYGCisGAQQB
# hFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAw
# DQYJKoZIhvcNAQELBQADggEBAGSqZCaaFtpBSEubOZWYI411RkHhNHrQZpDtjVfi
# wCmDICc5Rk0Pitn85eRh1XJz663DaMaDhR17VLtnh4QLHNIkmcVsUUQ52c6uWrNh
# rHemuWMRkhlr8lhz56JKCWR5Z4/2nHpgk2NZ2ccvHw0zQp3ODMNN4estMDf04fp+
# BDXLJ4h79RYrnI9iFhrfDbJCKlGIy8jCjmHzcSjQ71VmQ42D+Lt0DhH/crPd0lW1
# BKWTFJx3L4GIUG8zl9r0k46gDM6A0wGwLjuhHBpRJcjnsoyYRtMEKjFulho08cV3
# 35GugJTtdWBzuYzEte5j2cTB9/DB0NUrKNwWsvpsiDUvh58xggQNMIIECQIBATCB
# kzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAeqaJHLVWT9hYwAB
# AAAB6jANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJ
# EAEEMC8GCSqGSIb3DQEJBDEiBCC7qtYG33CC+7eZuA/d+6J3Dl5wW2bPCQeujY1X
# k+tEtzCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EICmPodXjZDR4iwg0ltLA
# NXBh5G1uKqKIvq8sjKekuGZ4MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTACEzMAAAHqmiRy1Vk/YWMAAQAAAeowIgQgj9rwyH7MIZidSUSrpDzY
# 42fQnJ6ggo9zn2sumN/DIG8wDQYJKoZIhvcNAQELBQAEggIArgQY1r9mRalezaJI
# +lHjZf+fEiEe+3pzy6n3SRyxKZ2J8VXk+TPCoQ4pMrzML2L90oSFsbuc+kLvGTWT
# /64idWui079nSIvsHV2yRV5L73xTIeYKg3rNqJD+wjklJ1zdxUxLPNJr9AeqMfcq
# u3E5VKgZzAXEzZJzx997UXsVEm3HEsF8EeUdZbKZ6WgtuimR3vf3OzNYn3OjYspZ
# Y+M9ang+OnEwSiDj7BRUmG4mLhz1kw0hhU+YV9912sSLJJEgP7xG3u8q2WXol07r
# uX+6f4B5YFLMFwKOdVFgBH8YKIBQ3VI+m3UT4x6WEaH6bB7o68Dgo/7iUTtZtKUe
# ///h06rEg08bP4phAKnW5Lb4VlZS7OOvRXyKU8GnwpltO847c9xLG6HL69b2mqJf
# wFJfdd2OQd17HI9bYk0QK+D9hAjogrWY4Mo0aAy0gzApx14I3BH8jA2tmb7Kp4aB
# PIZjo3IU2lV74f9AX9cxV6xAkuEntSRcAO4uWtXMkkS+P67CRskv3ymz7zJG9yHX
# 4kqxSZnssp6FWnrDi+5J5VKWr/xthPALmHRHAwwESNinaNEcx8rPFD2ReAoTEtIa
# WxHn1rJTiimZhYfwj56vL/HtwgjMFxOX8Kx1Nf2uuXoLyxhziD2XkIcnNyOsggyM
# E2hYnnUN+LTa4ZW050a+WgeWzHo=
# SIG # End signature block
