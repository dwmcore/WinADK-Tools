@echo off

set Tools_AutoUpdateFromNetwork=TRUE
set Tools_RELEASE_SHARE=\\mfperf\tools\WindowsXRay\latest

if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set XRayPath=windowsxray64
)

if /I "%PROCESSOR_ARCHITECTURE%"=="X86" (
    set XRayPath=windowsxray
)

if /I "%PROCESSOR_ARCHITECTURE%"=="ARM" (
    set XRayPath=windowsxray
)

if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set xraytools=TOOLS64
)

if /I "%PROCESSOR_ARCHITECTURE%"=="X86" (
    set xraytools=TOOLS
)

if /I "%PROCESSOR_ARCHITECTURE%"=="ARM" (
    set xraytools=TOOLSARM
)


if /i "%1"=="-n" (set Tools_AutoUpdateFromNetwork=FALSE)
if /i "%2"=="-n" (set Tools_AutoUpdateFromNetwork=FALSE)
if /i "%3"=="-n" (set Tools_AutoUpdateFromNetwork=FALSE)
if /i "%4"=="-n" (set Tools_AutoUpdateFromNetwork=FALSE)
if /i "%5"=="-n" (set Tools_AutoUpdateFromNetwork=FALSE)
if /i "%6"=="-n" (set Tools_AutoUpdateFromNetwork=FALSE)
if /i "%7"=="-n" (set Tools_AutoUpdateFromNetwork=FALSE)
if /i "%8"=="-n" (set Tools_AutoUpdateFromNetwork=FALSE)
if /i "%9"=="-n" (set Tools_AutoUpdateFromNetwork=FALSE)

echo.
echo ##########################################################
echo ###  Verify script is run from an elevated CMD prompt  ###
echo ##########################################################
echo.
if exist %windir%\system32\ntdll.dll.original (del %windir%\system32\ntdll.dll.original)
copy %windir%\system32\ntdll.dll %windir%\system32\ntdll.dll.original
if not exist %windir%\system32\ntdll.dll.original (goto ERR_ELEVATE_CMD_PROMPT)
del %windir%\system32\ntdll.dll.original

set APPDIR=%systemdrive%\%XRayPath%
if not exist %APPDIR% (md %APPDIR%) 
if not exist %APPDIR% (goto ERR_ELEVATE_CMD_PROMPT) 

set SCRIPTDIR=%APPDIR%\Scripts
if not exist %SCRIPTDIR% (md %SCRIPTDIR%) 
if not exist %SCRIPTDIR% (goto ERR_ELEVATE_CMD_PROMPT) 

set TRACEDUMP=%APPDIR%\Traces
if not exist %TRACEDUMP% (md %TRACEDUMP%) 
if not exist %TRACEDUMP% (goto ERR_ELEVATE_CMD_PROMPT) 

if /i "%Tools_AutoUpdateFromNetwork%"=="TRUE" (goto UpdateTools)
goto LaunchScript

:UpdateTools
echo.
echo ######################################
echo ######  Prep machine: Copy tools   ###
echo ######################################
echo.
if exist %Tools_RELEASE_SHARE%\collecttrace.cmd (copy %Tools_RELEASE_SHARE%\collecttrace.cmd %APPDIR%\ /y)
if not exist %APPDIR%\collecttrace.cmd (goto ERR_COPYING_TOOLS)

if exist %Tools_RELEASE_SHARE%\providers.cmd (copy %Tools_RELEASE_SHARE%\providers.cmd %SCRIPTDIR%\ /y)
if not exist %SCRIPTDIR%\providers.cmd (goto ERR_COPYING_TOOLS)

if exist %Tools_RELEASE_SHARE%\%xraytools%\GetMachineInfo.cmd (copy %Tools_RELEASE_SHARE%\%xraytools%\* %SCRIPTDIR%\ /y)
if not exist %SCRIPTDIR%\GetMachineInfo.cmd (goto ERR_COPYING_TOOLS)

:LaunchScript
echo.
echo ##########################################
echo ######  Launch Trace collection script ###
echo ##########################################
echo.

%systemdrive%
cd %APPDIR%
echo Launching %SCRIPTDIR%\gettraces.cmd %*
%SCRIPTDIR%\gettraces.cmd %*

goto EOF

:ERR_COPYING_TOOLS
echo.
echo #########################################
echo ######   ERROR Copying Tools!!!   #######
echo #########################################
echo.
echo  There was an error copying tools from %Tools_RELEASE_SHARE%
echo.
echo.
echo  Try doing a net use * /user:redmond\%your_alias% on the share above.
echo.
goto EOF

:ERR_ELEVATE_CMD_PROMPT
echo.
echo ############################
echo ######   ERROR !!!   #######
echo ############################
echo.
echo  Command prompt is not elevated!
echo.
echo  Launch command prompt in elevated mode
echo.
goto EOF

:EOF