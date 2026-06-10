@echo off
title VideoDiagnostic

:: Check for admin rights, relaunch if needed
openfiles >nul 2>&1
if errorlevel 1 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ============================
echo      VideoDiagnostic Menu
echo ============================
echo.
echo 1. Check Webcam Devices
echo 2. Uninstall Webcam Devices
echo 3. Reset Webcam Privacy Settings
echo 4. Restart Webcam Devices
echo 5. Update Webcam Drivers
echo 6. Configure Dual Monitor Setup
echo 7. Exit
echo.
set /p choice=Select an option (1-7):

if "%choice%"=="1" goto CheckWebcams
if "%choice%"=="2" goto UninstallWebcams
if "%choice%"=="3" goto ResetPrivacy
if "%choice%"=="4" goto RestartWebcams
if "%choice%"=="5" goto UpdateDrivers
if "%choice%"=="6" goto DualMonitor
if "%choice%"=="7" goto Exit
echo Invalid choice. Press any key to try again...
pause >nul
goto MENU

:CheckWebcams
echo Checking webcam devices...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"try { $webcams = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_PnPEntity | Where-Object { ($_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image') -and ($_.Name -notmatch 'Printer|OfficeJet|Fax|Scan|Copy') }; if ($webcams.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('No webcam devices were found on this system.', 'Webcam Status', 'OK', 'Warning') } else { $report = $webcams | ForEach-Object { \"Device Name: $($_.Name)`nStatus: $($_.Status)`nDevice ID: $($_.DeviceID)`n---------------------\" } | Out-String; [System.Windows.Forms.MessageBox]::Show($report, 'Webcam Devices Found', 'OK', 'Information') } } catch { [System.Windows.Forms.MessageBox]::Show('Error: '+$_.Exception.Message, 'Error', 'OK', 'Error') }"
pause
goto MENU

:UninstallWebcams
echo Uninstalling webcam devices...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$choice = [System.Windows.Forms.MessageBox]::Show('This will uninstall all detected webcam devices. Windows will reinstall drivers automatically.`nDo you want to continue?', 'Confirm Webcam Uninstall', 'YesNo', 'Warning'); if ($choice -eq 'Yes') { try { $webcams = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_PnPEntity | Where-Object { ($_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image') -and ($_.Name -notmatch 'Printer|OfficeJet|Fax|Scan|Copy') }; if (-not $webcams) { [System.Windows.Forms.MessageBox]::Show('No webcam devices detected.', 'Info', 'OK', 'Information'); exit } foreach ($cam in $webcams) { Remove-PnpDevice -InstanceId $cam.DeviceID -Confirm:$false -ErrorAction SilentlyContinue } [System.Windows.Forms.MessageBox]::Show('Uninstallation completed. Drivers will reinstall automatically.', 'Done', 'OK', 'Information') } catch { [System.Windows.Forms.MessageBox]::Show('Error: '+$_.Exception.Message, 'Error', 'OK', 'Error') } } else { [System.Windows.Forms.MessageBox]::Show('Operation cancelled.', 'Cancelled', 'OK', 'Information') }"
pause
goto MENU

:ResetPrivacy
echo Resetting webcam privacy settings...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"try { Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam' -Recurse -Force -ErrorAction SilentlyContinue; [System.Windows.Forms.MessageBox]::Show('Privacy settings reset. Restart may be required.', 'Privacy Reset', 'OK', 'Information') } catch { [System.Windows.Forms.MessageBox]::Show('Failed to reset privacy settings: '+$_.Exception.Message, 'Error', 'OK', 'Error') }"
pause
goto MENU

:RestartWebcams
echo Restarting webcam devices...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"try { $webcams = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_PnPEntity | Where-Object { ($_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image') -and ($_.Name -notmatch 'Printer|OfficeJet|Fax|Scan|Copy') }; if (-not $webcams) { [System.Windows.Forms.MessageBox]::Show('No webcam devices found.', 'Info', 'OK', 'Warning'); exit } foreach ($cam in $webcams) { Disable-PnpDevice -InstanceId $cam.PNPDeviceID -Confirm:$false -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2; Enable-PnpDevice -InstanceId $cam.PNPDeviceID -Confirm:$false -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 } [System.Windows.Forms.MessageBox]::Show('Webcam restart process completed successfully.', 'Restart', 'OK', 'Information') } catch { [System.Windows.Forms.MessageBox]::Show('Error during restart: '+$_.Exception.Message, 'Error', 'OK', 'Error') }"
pause
goto MENU

:UpdateDrivers
echo Updating webcam drivers...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { [System.Windows.MessageBox]::Show('Please run this tool as Administrator.', 'Insufficient Privileges', 'OK', 'Error'); exit } try { $webcams = Get-PnpDevice -Class 'Camera' -Status OK -ErrorAction SilentlyContinue; if (-not $webcams) { [System.Windows.MessageBox]::Show('No enabled webcam devices found.', 'No Devices', 'OK', 'Warning'); exit } foreach ($device in $webcams) { pnputil.exe /update-driver $device.InstanceId /install | Out-Null } [System.Windows.MessageBox]::Show('Webcam driver update completed.', 'Update', 'OK', 'Information') } catch { [System.Windows.MessageBox]::Show('Error: '+$_.Exception.Message, 'Error', 'OK', 'Error') }"
pause
goto MENU

:DualMonitor
echo Configuring dual monitor setup...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$resp = [System.Windows.Forms.MessageBox]::Show('Configure dual monitor setup to Extend mode?', 'Dual Monitor Setup', 'YesNo', 'Question'); if ($resp -eq 'Yes') { $monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams; if ($monitors.Count -lt 2) { [System.Windows.Forms.MessageBox]::Show('Less than two monitors detected.', 'Dual Monitor Setup', 'OK', 'Warning'); exit } Start-Process 'C:\Windows\System32\DisplaySwitch.exe' -ArgumentList '/extend' -Wait; [System.Windows.Forms.MessageBox]::Show('Dual monitor setup configured to Extend mode.', 'Dual Monitor Setup', 'OK', 'Information') } else { [System.Windows.Forms.MessageBox]::Show('Operation cancelled.', 'Cancelled', 'OK', 'Information') }"
pause
goto MENU

:Exit
exit
