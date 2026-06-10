@echo off
:: Request admin rights if not elevated
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title WindowsUpdateandSecurity

:MENU
cls
echo ===============================
echo   Windows Update and Security
echo ===============================
echo.
echo 1. Activation
echo 2. Recovery
echo 3. Troubleshoot
echo 0. Exit
echo.

set /p choice=Select an option [0-3]: 

if "%choice%"=="1" goto Activation
if "%choice%"=="2" goto Recovery
if "%choice%"=="3" goto Troubleshoot
if "%choice%"=="0" goto Exit

echo Invalid choice. Please try again.
pause
goto MENU

:Activation
start ms-settings:activation
call :LogAction "Opened Activation settings"
goto MENU

:Recovery
start ms-settings:recovery
call :LogAction "Opened Recovery settings"
goto MENU

:Troubleshoot
start ms-settings:troubleshoot
call :LogAction "Opened Troubleshoot settings"
goto MENU

:Exit
echo Exiting...
exit /b

:: Log actions to Windows Event Log under a custom source
:LogAction
setlocal
set "msg=%~1"
powershell -Command ^
 " $logName = 'Application';" ^
 " $source = 'BAT - WindowsUpdateandSecurity Launcher';" ^
 " if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {" ^
 "   try { New-EventLog -LogName $logName -Source $source } catch {} }" ^
 " Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message '%msg%';"
endlocal
exit /b
