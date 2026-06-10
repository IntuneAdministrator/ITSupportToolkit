@echo off
title AudioDiagnostic

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb runAs"
    exit /b
)

:MENU
cls
echo ========================================
echo           AudioDiagnostic v1.0
echo ========================================
echo.
echo 1. Uninstall Audio Devices
echo 2. Restart Audio Services
echo 3. Update Audio Drivers
echo 4. Open Volume Mixer
echo 5. Open Sound Settings
echo 6. Open Microphone Privacy Settings
echo 7. Open Classic Sound Control Panel
echo 8. Open Playback Devices (Volume Mixer)
echo 9. Restart WASAPI Service
echo 0. Exit
echo.
set /p choice=Select an option: 

if "%choice%"=="1" goto UninstallAudioDevices
if "%choice%"=="2" goto RestartAudioServices
if "%choice%"=="3" goto UpdateAudioDrivers
if "%choice%"=="4" goto OpenVolumeMixer
if "%choice%"=="5" goto OpenSoundSettings
if "%choice%"=="6" goto OpenMicrophonePrivacy
if "%choice%"=="7" goto OpenClassicSoundControl
if "%choice%"=="8" goto OpenPlaybackDevices
if "%choice%"=="9" goto RestartWASAPI
if "%choice%"=="0" exit

echo Invalid choice, try again.
pause
goto MENU

:UninstallAudioDevices
cls
echo Uninstalling active audio devices...
powershell -Command ^
" $audioDevices = Get-PnpDevice -Class Media -Status OK; ^
  if ($audioDevices.Count -eq 0) { Write-Output 'No active audio devices found.'; exit } ^
  $userConfirm = Read-Host 'This will uninstall all active audio devices. Type YES to continue'; ^
  if ($userConfirm -ne 'YES') { Write-Output 'Operation canceled.'; exit } ^
  foreach ($device in $audioDevices) { ^
    Write-Output ('Removing: {0}' -f $device.FriendlyName); ^
    pnputil /remove-device $device.InstanceId | Out-Null; ^
    Start-Sleep -Seconds 2 ^
  }; ^
  Write-Output 'Rescanning devices...'; ^
  pnputil /scan-devices; ^
  Write-Output 'Operation complete. Drivers will reinstall automatically. A reboot may be required.';"
pause
goto MENU

:RestartAudioServices
cls
echo Restarting audio services...
powershell -Command ^
" $services = @('AudioEndpointBuilder','Audiosrv'); ^
  foreach ($svc in $services) { ^
    Write-Output ('Restarting service: {0}' -f $svc); ^
    Restart-Service -Name $svc -Force -ErrorAction Stop; ^
    Start-Sleep -Seconds 2 ^
  }; ^
  Write-Output 'Audio services restarted successfully.';"
pause
goto MENU

:UpdateAudioDrivers
cls
echo Updating audio drivers for all active devices...
powershell -Command ^
" $audioDevices = Get-PnpDevice -Class Media -Status OK; ^
  if ($audioDevices.Count -eq 0) { Write-Output 'No audio devices to update.'; exit } ^
  foreach ($device in $audioDevices) { ^
    Write-Output ('Updating driver for: {0}' -f $device.FriendlyName); ^
    pnputil /update-driver $device.InstanceId /install | Out-Null; ^
    Start-Sleep -Seconds 1 ^
  }; ^
  Write-Output 'Audio drivers updated.';"
pause
goto MENU

:OpenVolumeMixer
cls
echo Opening Volume Mixer...
start ms-settings:apps-volume
timeout /t 2 >nul
goto MENU

:OpenSoundSettings
cls
echo Opening Sound Settings...
start ms-settings:sound
timeout /t 2 >nul
goto MENU

:OpenMicrophonePrivacy
cls
echo Opening Microphone Privacy Settings...
start ms-settings:privacy-microphone
timeout /t 2 >nul
goto MENU

:OpenClassicSoundControl
cls
echo Opening Classic Sound Control Panel...
start mmsys.cpl
timeout /t 2 >nul
goto MENU

:OpenPlaybackDevices
cls
echo Opening Playback Devices (Volume Mixer)...
start sndvol.exe
timeout /t 2 >nul
goto MENU

:RestartWASAPI
cls
echo Restarting WASAPI AudioEndpointBuilder service...
powershell -Command ^
" Restart-Service -Name 'AudioEndpointBuilder' -Force; ^
  Write-Output 'WASAPI AudioEndpointBuilder Service restarted successfully.';"
pause
goto MENU
