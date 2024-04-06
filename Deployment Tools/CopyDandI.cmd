@echo off
setlocal

set EXITCODE=0

rem
rem Input validation
rem
if /i "%1"=="/?" goto usage
if /i "%1"=="" goto usage
if /i "%~2"=="" goto usage
if /i not "%3"=="" goto usage

rem
rem Set environment variables for use in the script
rem
set TOOLS_ARCH=%1
set ARCH_EXISTS=1
set DEST=%~2

rem
rem Validate input architecture
rem
rem If the source directory as per input architecture does not exist,
rem it means the architecture is not present
rem
if not exist "%DandIRoot%\%TOOLS_ARCH%\DISM" set ARCH_EXISTS=0
if not exist "%WindowsSetupRootNoArch%\%TOOLS_ARCH%\sources" set ARCH_EXISTS=0
if not exist "%USMTRootNoArch%\%TOOLS_ARCH%" set ARCH_EXISTS=0
if not "%ARCH_EXISTS%" == "1" (
  echo ERROR: The following processor architecture was not found: %TOOLS_ARCH%.
  goto fail
)

rem
rem Make sure the destination directory does not exist
rem
if exist "%DEST%" (
  echo ERROR: Destination directory exists: "%DEST%".
  goto fail
)

mkdir "%DEST%"
if errorlevel 1 (
  echo ERROR: Unable to create destination: "%DEST%".
  goto fail
)

rem
rem Copy the DISM files
rem
xcopy /herky "%DandIRoot%\%TOOLS_ARCH%\DISM" "%DEST%\"
if errorlevel 1 (
  echo ERROR: Unable to copy DISM files: "%DandIRoot%\%TOOLS_ARCH%\DISM" to "%DEST%\".
  goto fail
)

rem
rem Copy the Windows Setup files
rem
xcopy /herky "%WindowsSetupRootNoArch%\%TOOLS_ARCH%\sources" "%DEST%\"
if errorlevel 1 (
  echo ERROR: Unable to copy Windows Setup files: "%WindowsSetupRootNoArch%\%TOOLS_ARCH%\sources" to "%DEST%\".
  goto fail
)

rem
rem Copy the USMT files
rem
xcopy /herky "%USMTRootNoArch%\%TOOLS_ARCH%" "%DEST%\"
if errorlevel 1 (
  echo ERROR: Unable to copy USMT files: "%USMTRootNoArch%\%TOOLS_ARCH%" to "%DEST%\".
  goto fail
)

:success
set EXITCODE=0
echo.
echo Success
echo.
goto cleanup

:usage
set EXITCODE=1
echo Copies all deployment and imaging related tools to a specified folder.
echo.
echo CopyDandI { amd64 ^| x86 ^| arm ^| arm64 } ^<destinationDirectory^>
echo.
echo  amd64                 Copies amd64 tools to ^<workingDirectory^>\.
echo  x86                   Copies x86 tools to ^<workingDirectory^>\.
echo  arm                   Copies arm tools to ^<workingDirectory^>\.
echo  arm64                 Copies arm64 tools to ^<workingDirectory^>\.
echo                        Note: ARM/ARM64 content may not be present in this ADK.
echo  destinationDirectory  Creates the working directory at the specified location.
echo.
echo Example: CopyDandI amd64 F:\DeploymentTools
goto cleanup

:fail
set EXITCODE=1
echo Failed!
goto cleanup

:cleanup
endlocal & exit /b %EXITCODE%
