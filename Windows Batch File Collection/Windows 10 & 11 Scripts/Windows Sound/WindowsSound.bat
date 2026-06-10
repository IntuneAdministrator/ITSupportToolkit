@echo off
:: Request admin rights
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title WindowsSound

:MENU
cls
echo ===========================
echo     Windows Sound Settings
echo ===========================
echo.
echo 1. Volume mixer
echo 2. Sound
echo 3. Sound devices
echo 4. Default microphone
echo 5. Default audio output
echo 0. Exit
echo.

set /p choice=Select an option [0-5]: 

if "%choice%"=="1" goto VolumeMixer
if "%choice%"=="2" goto Sound
if "%choice%"=="3" goto SoundDevices
if "%choice%"=="4" goto DefaultMic
if "%choice%"=="5" goto DefaultAudioOutput
if "%choice%"=="0" goto Exit

echo Invalid choice. Try again.
pause
goto MENU

:VolumeMixer
start ms-settings:apps-volume
call :LogAction "Opened Volume mixer sound settings"
goto MENU

:Sound
start ms-settings:sound
call :LogAction "Opened Sound settings"
goto MENU

:SoundDevices
start ms-settings:sound-devices
call :LogAction "Opened Sound devices settings"
goto MENU

:DefaultMic
start ms-settings:sound-defaultinputproperties
call :LogAction "Opened Default microphone sound settings"
goto MENU

:DefaultAudioOutput
start ms-settings:sound-defaultoutputproperties
call :LogAction "Opened Default audio output sound settings"
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
 " $source = 'BAT - WindowsSound Launcher';" ^
 " if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {" ^
 "   try { New-EventLog -LogName $logName -Source $source } catch {} }" ^
 " Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message '%msg%';"
endlocal
exit /b
