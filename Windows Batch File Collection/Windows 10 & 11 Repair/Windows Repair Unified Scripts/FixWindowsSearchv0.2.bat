@echo off
title FixWindowsSearchv0.2

:: Check for admin rights
net session >nul 2>&1
if errorlevel 1 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ===========================================
echo          Fix Windows Search Tool v0.2
echo ===========================================
echo.
echo 1. Restart Font Cache Service
echo 2. Check for Windows Updates (Start Scan)
echo 3. Run Search Troubleshooter
echo 4. Restart SearchHost.exe Process
echo 5. Reset Windows Search Package
echo 6. Clean Registry and AppData
echo 7. Exit
echo.
set /p choice=Enter your choice (1-7): 

if "%choice%"=="1" goto RestartFontCache
if "%choice%"=="2" goto CheckUpdates
if "%choice%"=="3" goto RunTroubleshooter
if "%choice%"=="4" goto RestartSearchHost
if "%choice%"=="5" goto ResetWindowsSearch
if "%choice%"=="6" goto CleanupRegistryAppData
if "%choice%"=="7" goto Exit

echo Invalid choice. Please try again.
pause
goto MENU

:RestartFontCache
echo Restarting Font Cache Service...
sc stop FontCache >nul 2>&1
timeout /t 2 >nul
sc start FontCache >nul 2>&1
if errorlevel 1 (
    echo Failed to restart Font Cache Service.
) else (
    echo Font Cache Service restarted successfully.
)
pause
goto MENU

:CheckUpdates
echo Starting Windows Update scan...
start /wait UsoClient.exe StartScan
if errorlevel 1 (
    echo Failed to start Windows Update scan.
) else (
    echo Windows Update scan started.
)
pause
goto MENU

:RunTroubleshooter
echo Launching Search Troubleshooter...
start msdt.exe -ep WindowsHelp id SearchDiagnostic
echo Troubleshooter launched.
pause
goto MENU

:RestartSearchHost
echo Restarting SearchHost.exe process...
taskkill /IM SearchHost.exe /F >nul 2>&1
if errorlevel 1 (
    echo No SearchHost.exe process found or failed to terminate.
) else (
    echo SearchHost.exe process restarted.
)
pause
goto MENU

:ResetWindowsSearch
echo Resetting Windows Search package...
powershell -Command ^
"Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force; ^
$manifest = 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\AppxManifest.xml'; ^
if (Test-Path $manifest) { Add-AppxPackage -Path $manifest -DisableDevelopmentMode -Register }; ^
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Restricted -Force"
if errorlevel 1 (
    echo Failed to reset Windows Search package.
) else (
    echo Windows Search package reset successfully.
    echo A restart is recommended.
    set /p restart=Restart now? (Y/N): 
    if /I "%restart%"=="Y" (
        echo Restarting computer...
        shutdown /r /t 5
        exit
    )
)
pause
goto MENU

:CleanupRegistryAppData
echo Cleaning Registry and AppData...
powershell -Command ^
"$appData = '$env:LOCALAPPDATA\Packages\MicrosoftWindows.Client.CBS_cw5n1h2txyewy'; ^
if (Test-Path $appData) { Remove-Item -Path $appData -Recurse -Force -ErrorAction SilentlyContinue }; ^
$regKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; ^
if (Test-Path $regKey) { Remove-Item -Path $regKey -Recurse -Force -ErrorAction SilentlyContinue }"
if errorlevel 1 (
    echo Failed to clean Registry and AppData.
) else (
    echo Cleanup complete.
    set /p restart=Restart now? (Y/N): 
    if /I "%restart%"=="Y" (
        echo Restarting computer...
        shutdown /r /t 5
        exit
    )
)
pause
goto MENU

:Exit
echo Exiting Fix Windows Search Tool.
exit /b
