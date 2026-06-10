@echo off
:: Request admin rights
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title WindowsPrivacy

:MENU
cls
echo ========================
echo      Windows Privacy
echo ========================
echo.
echo 1. Account info
echo 2. Camera
echo 3. Microphone
echo 0. Exit
echo.

set /p choice=Select an option [0-3]: 

if "%choice%"=="1" goto AccountInfo
if "%choice%"=="2" goto Camera
if "%choice%"=="3" goto Microphone
if "%choice%"=="0" goto Exit

echo Invalid choice. Try again.
pause
goto MENU

:AccountInfo
start ms-settings:privacy-accountinfo
call :LogAction "Opened Account info privacy settings"
goto MENU

:Camera
start ms-settings:privacy-webcam
call :LogAction "Opened Camera privacy settings"
goto MENU

:Microphone
start ms-settings:privacy-microphone
call :LogAction "Opened Microphone privacy settings"
goto MENU

:Exit
echo Exiting...
exit /b

:: Logs action to Windows Event Log
:LogAction
setlocal
set "msg=%~1"
powershell -Command ^
 " $logName = 'Application';" ^
 " $source = 'BAT - WindowsPrivacy Launcher';" ^
 " if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {" ^
 "   try { New-EventLog -LogName $logName -Source $source } catch {} }" ^
 " Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message '%msg%';"
endlocal
exit /b
