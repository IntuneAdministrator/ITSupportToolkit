@echo off
:: SpeedUpComputer.bat - Admin Menu for Performance Tweaks
:: Requires admin rights

:: Title
title SpeedUpComputer - Windows Performance Tweaks

:: Check for Admin Rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb runAs"
    exit /b
)

:MENU
cls
echo ===============================================
echo         Speed Up Windows Computer Tweaks
echo ===============================================
echo.
echo 1. Uninstall Extra Antivirus Programs
echo 2. Disable Startup Programs (Task Manager)
echo 3. Run Check Disk on C:
echo 4. Defragment Hard Disk C:
echo 5. Turn Off Visual Effects (Performance Options)
echo 6. Temporarily Disable Windows Search Service
echo 7. Disable SysMain (Superfetch) Service
echo 8. Exit
echo.
set /p choice=Choose an option [1-8]:

REM Handle choices
if "%choice%"=="1" goto UninstallAV
if "%choice%"=="2" goto DisableStartup
if "%choice%"=="3" goto RunCheckDisk
if "%choice%"=="4" goto DefragDisk
if "%choice%"=="5" goto TurnOffVisualEffects
if "%choice%"=="6" goto DisableWinSearch
if "%choice%"=="7" goto DisableSysMain
if "%choice%"=="8" goto End

echo Invalid choice, try again.
pause
goto MENU

:UninstallAV
echo Opening Programs & Features for uninstalling antivirus...
start appwiz.cpl
goto PauseAndReturn

:DisableStartup
echo Opening Task Manager Startup tab...
start taskmgr.exe /startup
goto PauseAndReturn

:RunCheckDisk
echo Running CHKDSK on C: (read-only)...
chkdsk C:
echo Press any key to continue after CHKDSK finishes.
pause >nul
goto PauseAndReturn

:DefragDisk
echo Starting defragmentation of C: drive (this may take a while)...
defrag C: -w -v
echo Defragmentation completed.
pause
goto PauseAndReturn

:TurnOffVisualEffects
echo Opening Performance Options...
start SystemPropertiesPerformance.exe
goto PauseAndReturn

:DisableWinSearch
echo Temporarily stopping Windows Search service...
sc queryex WSearch >nul 2>&1
if errorlevel 1 (
    echo Windows Search service not found.
) else (
    net stop WSearch
    echo Windows Search service stopped temporarily.
)
pause
goto PauseAndReturn

:DisableSysMain
echo Disabling SysMain (Superfetch) service...
sc queryex SysMain >nul 2>&1
if errorlevel 1 (
    echo SysMain service not found.
) else (
    sc config SysMain start= disabled
    net stop SysMain
    echo SysMain service disabled.
)
pause
goto PauseAndReturn

:PauseAndReturn
echo.
pause
goto MENU

:End
echo Exiting SpeedUpComputer.
exit /b
