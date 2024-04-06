<#
Copyright (c) Microsoft Corporation.  All rights reserved.
#>

<#
Update-AppvPackageMsi.ps1 
 
 This script is used to update an App-V package MSI file allowing the MSI to be successfully
 installed on all versions of App-V 5.0 and greater, including the App-V version that ships
 in-box as part of Windows 10. The success of these operations cannot be guaranteed if this file has 
 been altered.
#>

<#
.SYNOPSIS
    Updates an App-V package MSI file allowing the MSI to be successfully
    installed on all versions of App-V 5.0 and greater, including the App-V version that ships
    in-box as part of Windows 10.

.DESCRIPTION
    App-V package MSI files perform a prerequisite check to verify that App-V is installed on the device before allowing
    the MSI install to proceed. On Windows versions where App-V is included in-box, this prerequisite check will
    fail because App-V is no longer installed from an MSI package. This command will edit the specified App-V package 
    MSI file and fix up the launch conditions to allow it to be installed successfully on all versions of App-V 5.0 
    and greater.

    The 'Microsoft Windows Installer Software Development Kit (SDK)' is required for this cmdlet to run properly.
    The 'Microsoft Windows Installer SDK is included in the 'Microsoft Windows Software Development Kit (SDK)',
    which can be downloaded from https://go.microsoft.com/fwlink/p/?linkid=162443.

.EXAMPLE
    Update-AppvPackageMsi -MsiPackage "C:\App-V Packages\MyVirtualApp.msi" -MsiDbPath "C:\Program Files (x86)\Windows Kits\10\bin\x86"

.PARAMETER MsiPackage
    The path to the App-V package MSI file

.PARAMETER MsiDbPath
    The path to where msidb.exe is present (obtained by installing the 'Microsoft Windows Installer Software Development Kit (SDK)'
#>
[CmdletBinding()]
Param
(
    [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
    [string]$msiPackage,
    [parameter(Mandatory=$true)]
    [string]$msiDbPath
)

Function Update-AppvPackageMsi($msiPackage, $msiDbPath)
{
begin
{
    # There are two versions of launch conditions that need to be updated or removed.
    $oldLaunchConditionv1 = 'NOT APPV_CLIENT_INSTALLED'
    $oldLaunchConditionv2 = 'Installed OR APPV_CLIENT_INSTALLED'
    $newLaunchCondition   = 'Installed OR APPV_CLIENT_5X_OR_GREATER_INSTALLED'

    Validate-NotNetworkPath $msiDbPath

    $msidbExe = Join-Path -Path $msiDbPath -ChildPath "\MsiDb.exe"
    if (!(Test-Path $msidbExe))
    {
        Display-CriticalError "Cannot locate the 'MsiDb.exe' file. Please either specify the path to the 'Windows Installer SDK' `
            or install the 'Microsoft Windows Software Development Kit (SDK)' on this device `
            (https://www.microsoft.com/en-us/download/details.aspx?id=3138)."
    }
}

process
{
    Validate-NotNetworkPath $msiPackage

    # Verify that the App-V package MSI exists.
    if (!(Test-Path $msiPackage))
    {
        Display-CriticalError "Invalid parameter - App-V package MSI file '$msiPackage' does not exist."
    }

    $tempFolder = Create-TempDirectory
    $tableFile = Join-Path -Path $tempFolder -ChildPath 'LaunchCondition.idt'

    Export-LaunchConditions $msidbExe $msiPackage $tempFolder
    $content = Get-Content "$tableFile" -ErrorAction SilentlyContinue
    if ($content.Length -eq 0)
    {
        Display-CriticalError "Could not read LaunchCondition table file."
    }
    
    # Don't do anything, if this MSI has already been updated.
    if (@($content | Where-Object {$_.Contains($newLaunchCondition)}).Count -eq 0)
    {
        $content -replace $oldLaunchConditionv1, $newLaunchCondition -replace $oldLaunchConditionv2, $newLaunchCondition | Set-Content $tableFile
        Import-LaunchConditions $msiDbExe $msiPackage $tempFolder
        Add-AppSearchTables $msiDbExe $msiPackage $tempFolder
        Write-Output "App-V MSI package '$msiPackage' has been successfully updated."
    }
    else
    {
        Write-Output "App-V MSI package '$msiPackage' has been previously updated."
    }

    Remove-Item $tempFolder -Recurse
}
}

# Adds and modifies all of the necessary tables to the MSI to perform an AppSearch
Function Add-AppSearchTables($msidb, $pkgPath, $importFolderPath)
{
    [string[]] $signatureTextString = 
        "Signature`tFileName`tMinVersion`tMaxVersion`tMinSize`tMaxSize`tMinDate`tMaxDate`tLanguages", 
        "s72`ts255`tS20`tS20`tI4`tI4`tI4`tI4`tS255", 
        "Signature`tSignature"
    Add-Table $msidb $pkgPath $importFolderPath $signatureTextString "Signature.idt"

    [string[]] $appSearchTextString = 
        "Property`tSignature_",
        "s72`ts72", 
        "AppSearch`tProperty`tSignature_", 
        "APPV_CLIENT_5X_OR_GREATER_INSTALLED`tAppVClientVersionKey"
    Add-Table $msidb $pkgPath $importFolderPath $appSearchTextString "AppSearch.idt"

    [string[]] $regLocatorTextString = 
        "Signature_`tRoot`tKey`tName`tType", 
        "s72`ti2`ts255`tS255`tI2", 
        "RegLocator`tSignature_", 
        "AppVClientVersionKey`t2`tSoftware\Microsoft\AppV\Client`tVersion`t18"
    Add-Table $msidb $pkgPath $importFolderPath $regLocatorTextString "RegLocator.idt"
    
    [string[]] $installExecuteSequenceTextString = 
        "AppSearch`t`t50"
    Update-Table $msidb $pkgPath $importFolderPath $installExecuteSequenceTextString "InstallExecuteSequence"

    [string[]] $installUISequenceTextString = 
        "AppSearch`t`t50"
    Update-Table $msidb $pkgPath $importFolderPath $installUISequenceTextString "InstallUISequence"

    [string[]] $_validationTextString = 
        "AppSearch`tProperty`tN`t`t`t`t`tIdentifier`t`tThe property associated with a Signature", 
        "AppSearch`tSignature_`tN`t`t`tSignature;RegLocator;IniLocator;DrLocator;CompLocator`t1`tIdentifier`t`tThe Signature_ represents a unique file signature and is also the foreign key in the Signature,  RegLocator, IniLocator, CompLocator and the DrLocator tables.",
        "RegLocator`tKey`tN`t`t`t`t`tRegPath`t`tThe key for the registry value.",
        "RegLocator`tName`tY`t`t`t`t`tFormatted`t`tThe registry value name.",
        "RegLocator`tRoot`tN`t0`t3`t`t`t`t`tThe predefined root key for the registry value, one of rrkEnum.",
        "RegLocator`tSignature_`tN`t`t`t`t`tIdentifier`t`tThe table key. The Signature_ represents a unique file signature and is also the foreign key in the Signature table. If the type is 0, the registry values refers a directory, and _Signature is not a foreign key.",
        "RegLocator`tType`tY`t0`t18`t`t`t`t`tAn integer value that determines if the registry value is a filename or a directory location or to be used as is w/o interpretation.",
        "Signature`tFileName`tN`t`t`t`t`tFilename`t`tThe name of the file. This may contain a `"short name|long name`" pair.",
        "Signature`tLanguages`tY`t`t`t`t`tLanguage`t`tThe languages supported by the file.",
        "Signature`tMaxDate`tY`t0`t2147483647`t`t`t`t`tThe maximum creation date of the file.",
        "Signature`tMaxSize`tY`t0`t2147483647`t`t`t`t`tThe maximum size of the file.",
        "Signature`tMaxVersion`tY`t`t`t`t`tText`t`tThe maximum version of the file.",
        "Signature`tMinDate`tY`t0`t2147483647`t`t`t`t`tThe minimum creation date of the file.",
        "Signature`tMinSize`tY`t0`t2147483647`t`t`t`t`tThe minimum size of the file.",
        "Signature`tMinVersion`tY`t`t`t`t`tText`t`tThe minimum version of the file.",
        "Signature`tSignature`tN`t`t`t`t`tIdentifier`t`tThe table key. The Signature represents a unique file signature."
    Update-Table $msidb $pkgPath $importFolderPath $_validationTextString "_Validation"
}


# Adds the specified table to the MSI
Function Add-Table($msidb, $pkgPath, $importFolderPath, $tableTextContent, $tableTextFilename)
{
    $tableTextContent | Set-Content (Join-Path -Path $importFolderPath -ChildPath $tableTextFilename)

    $args = @('-d"{0}" -f"{1}" -i {2}' -f $pkgPath, $importFolderPath, $tableTextFilename)
    $p = Start-Process $msidb -ArgumentList $args -Wait -NoNewWindow -PassThru
    if ($p.ExitCode -ne 0)
    {
        Display-CriticalError ("Failed to import {0} from '{1}'. Exit code = {2}" -f $tableTextFilename, $pkgPath, $p.ExitCode)
    }
}


# Create a temporary, unique directory.
Function Create-TempDirectory
{
    $parent = [System.IO.Path]::GetTempPath()
    [string] $dirName = [System.Guid]::NewGuid()
    return New-Item -ItemType Directory -Path (Join-Path -Path $parent -ChildPath $dirName)
}


# Display a terminating error message.
Function Display-CriticalError($errorMessage)
{
    $exMessage = New-Object Exception $errorMessage
    $PSCmdlet.ThrowTerminatingError((New-Object Management.Automation.ErrorRecord $exMessage, $null, 0, $null))
}


# Export the LaunchConditions table to a file.
Function Export-LaunchConditions($msidb, $pkgPath, $exportFolderPath)
{
    $args = @('-d"{0}" -f"{1}" -e LaunchCondition' -f $pkgPath, $exportFolderPath)
    $p = Start-Process $msidb -ArgumentList $args -Wait -NoNewWindow -PassThru
    if ($p.ExitCode -ne 0)
    {
        Display-CriticalError ("Failed to export LaunchConditions table from '{0}'. Exit code = {1}" -f $pkgPath, $p.ExitCode)
    }
}


# Import into the LaunchConditions table from a file.
Function Import-LaunchConditions($msidb, $pkgPath, $importFolderPath)
{
    $args = @('-d"{0}" -f"{1}" -i LaunchCondition.idt' -f $pkgPath, $importFolderPath)
    $p = Start-Process $msidb -ArgumentList $args -Wait -NoNewWindow -PassThru
    if ($p.ExitCode -ne 0)
    {
        Display-CriticalError ("Failed to import LaunchConditions table from '{0}'. Exit code = {1}" -f $pkgPath, $p.ExitCode)
    }
}


# Updates the specified MSI table
Function Update-Table($msidb, $pkgPath, $mergeFolderPath, $mergeTextContent, $tableName)
{
    $args = @('-d"{0}" -f"{1}" -e {2}' -f $pkgPath, $mergeFolderPath, $tableName)
    $p = Start-Process $msidb -ArgumentList $args -Wait -NoNewWindow -PassThru
    if ($p.ExitCode -ne 0)
    {
        Display-CriticalError ("Failed to export {0} from '{1}'. Exit code = {2}" -f $tableName, $pkgPath, $p.ExitCode)
    }

    $tableTextFilename = $tableName + ".idt"
    $tableTextFilePath = Join-Path -Path $mergeFolderPath -ChildPath $tableTextFilename

    $content = Get-Content "$tableTextFilePath" -ErrorAction SilentlyContinue
    if ($content.Length -eq 0)
    {
        Display-CriticalError "Could not read '$tableTextFilePath' table file."
    } 

    $collection = {$content}.Invoke()
    $mergeTextContent | Foreach-Object {$collection.Add($_)}

    $collection | Set-Content $tableTextFilePath

    $args = @('-d"{0}" -f"{1}" -i {2}' -f $pkgPath, $mergeFolderPath, $tableTextFilename)
    $p = Start-Process $msidb -ArgumentList $args -Wait -NoNewWindow -PassThru
    if ($p.ExitCode -ne 0)
    {
        Display-CriticalError ("Failed to import {0} from '{1}'. Exit code = {2}" -f $tableTextFilename, $pkgPath, $p.ExitCode)
    }
}


# MsiDb.exe doesn't handle UNC or network paths.
Function Validate-NotNetworkPath([string]$path)
{
    if ($path.StartsWith('\\'))
    {
        Display-CriticalError "UNC file paths are not supported."
    }

    $drive = New-Object System.IO.DriveInfo(Resolve-Path $path)
    if ($drive.DriveType -eq 'Network')
    {
        Display-CriticalError "Network file paths are not supported."
    }
}

Update-AppvPackageMsi $msiPackage $msiDbPath
