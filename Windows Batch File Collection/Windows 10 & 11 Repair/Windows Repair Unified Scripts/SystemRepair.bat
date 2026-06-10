@echo off
:: Title and request admin rights
title SystemRepair

:: Check for admin rights
net session >nul 2>&1
if errorlevel 1 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ===========================
echo      System Repair Menu
echo ===========================
echo 1. Restart Print Spooler
echo 2. Fix Windows Search
echo 3. Delete Temporary Files
echo 4. Clean Browsing Data
echo 5. Reset Graphics Driver
echo 6. Create Temporary Admin User
echo 7. Start System Repair (DISM/SFC)
echo 8. Remove Default Microsoft Store Apps
echo 9. Full System Repair Tasks
echo 0. Exit
echo ===========================
set /p choice=Choose an option (0-9): 

if "%choice%"=="1" goto RestartPrintSpooler
if "%choice%"=="2" goto FixWindowsSearch
if "%choice%"=="3" goto DeleteTempFiles
if "%choice%"=="4" goto CleanBrowsingData
if "%choice%"=="5" goto ResetGraphicsDriver
if "%choice%"=="6" goto CreateTempAdminUser
if "%choice%"=="7" goto DISM_SFC
if "%choice%"=="8" goto RemoveStoreApps
if "%choice%"=="9" goto FullSystemRepair
if "%choice%"=="0" goto Exit

echo Invalid choice. Press any key to try again...
pause >nul
goto MENU

:: Restart Print Spooler
:RestartPrintSpooler
echo Restarting Print Spooler...
net stop spooler
net start spooler
echo Done.
pause
goto MENU

:: Fix Windows Search
:FixWindowsSearch
echo Fixing Windows Search...
powershell -Command "Get-Service WSearch | Restart-Service"
echo Done.
pause
goto MENU

:: Delete Temporary Files
:DeleteTempFiles
echo Deleting Temporary Files...
del /q /f /s "%TEMP%\*.*" >nul 2>&1
del /q /f /s "C:\Windows\Temp\*.*" >nul 2>&1
echo Done.
pause
goto MENU

:: Clean Browsing Data (for Edge)
:CleanBrowsingData
echo Cleaning Browsing Data for Microsoft Edge...
powershell -Command "Remove-Item -Path \"$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\" -Recurse -Force"
echo Done.
pause
goto MENU

:: Reset Graphics Driver
:ResetGraphicsDriver
echo Resetting Graphics Driver...
:: Windows key + Ctrl + Shift + B triggers graphics driver reset
powershell -Command "$code = [System.Windows.Forms.SendKeys]::SendWait('^{+}{B}')"
echo Done.
pause
goto MENU

:: Create Temporary Admin User
:CreateTempAdminUser
echo Creating Temporary Admin User...
powershell -Command ^
"New-LocalUser -Name 'TempAdminUser' -Password (ConvertTo-SecureString 'TempP@ssw0rd!' -AsPlainText -Force) -FullName 'Temporary Admin' -Description 'Temporary Admin User'; ^
Add-LocalGroupMember -Group Administrators -Member 'TempAdminUser'"
echo Temporary admin user 'TempAdminUser' created with password 'TempP@ssw0rd!'
pause
goto MENU

:: Start System Repair (DISM/SFC)
:DISM_SFC
echo Running DISM and SFC...
powershell -Command ^
"dism.exe /Online /Cleanup-Image /RestoreHealth; ^
sfc.exe /scannow"
echo Done.
pause
goto MENU

:: Remove Default Microsoft Store Apps
:RemoveStoreApps
echo Removing Default Microsoft Store Apps...
powershell -Command ^
"$packages = @('Clipchamp.Clipchamp_yxz26nhyzhsrt','Microsoft.BingNews_8wekyb3d8bbwe','Microsoft.BingWeather_8wekyb3d8bbwe','Microsoft.GamingApp_8wekyb3d8bbwe','Microsoft.MediaPlayer_8wekyb3d8bbwe','Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe','Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe','Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe','Microsoft.OutlookForWindows_8wekyb3d8bbwe','Microsoft.Paint_8wekyb3d8bbwe','Microsoft.ScreenSketch_8wekyb3d8bbwe','Microsoft.Todos_8wekyb3d8bbwe','Microsoft.Windows.Photos_8wekyb3d8bbwe','Microsoft.WindowsCalculator_8wekyb3d8bbwe','Microsoft.WindowsCamera_8wekyb3d8bbwe','Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe','Microsoft.WindowsNotepad_8wekyb3d8bbwe','Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe','Microsoft.Xbox.TCUI_8wekyb3d8bbwe','Microsoft.XboxGamingOverlay_8wekyb3d8bbwe','Microsoft.XboxIdentityProvider_8wekyb3d8bbwe','Microsoft.XboxSpeechToTextOverlay_8wekyb3d8bbwe','Microsoft.ZuneMusic_8wekyb3d8bbwe','Microsoft.ZuneVideo_8wekyb3d8bbwe','MicrosoftTeams_8wekyb3d8bbwe','7EE7776C.LinkedInforWindows_w1wdnht996qgy','Microsoft.Copilot_8wekyb3d8bbwe'); ^
foreach ($pkg in $packages) { ^
    Get-AppxPackage -Name $pkg -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue; ^
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -EQ $pkg | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue ^
}"
echo Done.
pause
goto MENU

:: Full System Repair Tasks (bootrec, chkdsk, sfc, dism)
:FullSystemRepair
echo Starting full system repair tasks...

echo Running bootrec /fixmbr
bootrec.exe /fixmbr

echo Running bootrec /fixboot
bootrec.exe /fixboot

echo Running bootrec /scanos
bootrec.exe /scanos

echo Running chkdsk /f /r C:
chkdsk.exe /f /r C:

echo Running sfc /scannow
sfc.exe /scannow

echo Running DISM /Online /Cleanup-Image /RestoreHealth
dism.exe /Online /Cleanup-Image /RestoreHealth

echo System repair tasks completed.
echo It is recommended to restart your computer.

pause
goto MENU

:Exit
echo Exiting SystemRepair. Goodbye!
exit /b
