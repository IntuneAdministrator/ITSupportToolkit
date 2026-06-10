@echo off
title UpdateDiagnostic
color 0A

:: Check for admin rights
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo.
    echo *** Administrator privileges are required to run this script. ***
    echo Please approve the UAC prompt.
    pause
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:menu
cls
echo ==============================
echo   Update Diagnostic Menu
echo ==============================
echo.
echo 1. Update Windows Drivers (via Windows Update)
echo 2. Upgrade All Packages (winget)
echo 3. Install Windows Updates (PSWindowsUpdate)
echo 4. Force Group Policy Update
echo 5. Run Windows Update Repair
echo 6. Exit
echo.
set /p choice=Choose an option [1-6]:

if "%choice%"=="1" goto UpdateDrivers
if "%choice%"=="2" goto WingetUpgrade
if "%choice%"=="3" goto PSWUInstall
if "%choice%"=="4" goto GPUpdate
if "%choice%"=="5" goto RepairWindows
if "%choice%"=="6" exit

echo Invalid choice, try again.
pause
goto menu


:UpdateDrivers
cls
echo Updating Windows Drivers via Windows Update...
echo Please wait, this may take several minutes.
powershell -Command "Write-Output 'Starting driver update...'; Start-Process -FilePath 'powershell' -ArgumentList '-Command', 'pnputil /scan-devices' -Wait"
echo Driver update command issued.
pause
goto menu


:WingetUpgrade
cls
echo Upgrading all packages using winget...
echo Please wait, this may take some time.
powershell -Command "winget upgrade --all --accept-source-agreements --accept-package-agreements"
echo Upgrade process completed.
pause
goto menu


:PSWUInstall
cls
echo Installing Windows Updates using PSWindowsUpdate module...
echo This requires PSWindowsUpdate module installed.
powershell -Command ^
"if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) { Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser };" ^
"Import-Module PSWindowsUpdate;" ^
"Get-WindowsUpdate -Install -AcceptAll -AutoReboot"
pause
goto menu


:GPUpdate
cls
echo Forcing Group Policy update...
gpupdate /force
echo Group Policy update completed.
pause
goto menu


:RepairWindows
cls
echo Running Windows Update repair steps...
echo This may take a while, please wait.

echo Stopping Windows Update services...
net stop wuauserv
net stop cryptSvc
net stop bits
net stop msiserver

echo Renaming SoftwareDistribution and Catroot2 folders...
ren C:\Windows\SoftwareDistribution SoftwareDistribution.old
ren C:\Windows\System32\catroot2 catroot2.old

echo Restarting Windows Update services...
net start wuauserv
net start cryptSvc
net start bits
net start msiserver

echo Running DISM CheckHealth...
dism /Online /Cleanup-Image /CheckHealth

echo Running DISM ScanHealth...
dism /Online /Cleanup-Image /ScanHealth

echo Running DISM RestoreHealth...
dism /Online /Cleanup-Image /RestoreHealth

echo Running System File Checker (SFC)...
sfc /scannow

echo.
echo Windows Update repair process completed.
pause
goto menu
