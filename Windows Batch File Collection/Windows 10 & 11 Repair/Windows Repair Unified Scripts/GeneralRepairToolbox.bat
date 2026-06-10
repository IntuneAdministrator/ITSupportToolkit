@echo off
title GeneralRepairToolbox

:: Check for admin rights by trying to create a folder in system32 (will fail without admin)
>nul 2>&1 "%SystemRoot%\system32\cacls.exe" "%SystemRoot%\system32\config\system"

if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else (
    goto MainMenu
)

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0""", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /b

:MainMenu
cls
echo ===============================
echo  General Repair Toolbox
echo ===============================
echo.
echo 1. Run Network Troubleshooter
echo 2. Reset Network Adapters (requires reboot prompt)
echo 3. Clear Windows Store Cache
echo 4. Repair Windows Update
echo 5. Check Disk for Errors (read-only scan)
echo 6. Restart Windows Explorer
echo 7. Clear Temporary Internet Files
echo 8. Reset Printer Queue
echo 9. Run System File Checker (SFC)
echo 0. Exit
echo.
set /p choice=Choose an option (0-9): 

if "%choice%"=="1" goto RunNetworkTroubleshooter
if "%choice%"=="2" goto ResetNetworkAdapters
if "%choice%"=="3" goto ClearWSCache
if "%choice%"=="4" goto RepairWindowsUpdate
if "%choice%"=="5" goto CheckDisk
if "%choice%"=="6" goto RestartExplorer
if "%choice%"=="7" goto ClearBrowserCache
if "%choice%"=="8" goto ResetPrintQueue
if "%choice%"=="9" goto RunSFC
if "%choice%"=="0" goto Exit

echo Invalid option. Please try again.
pause
goto MainMenu

:RunNetworkTroubleshooter
echo Launching Network Troubleshooter...
start msdt.exe /id NetworkDiagnosticsNetworkAdapter
echo Press any key to return to menu...
pause >nul
goto MainMenu

:ResetNetworkAdapters
echo Resetting Network Adapters...

ipconfig /flushdns
netsh int ip reset
netsh winsock reset

echo Network adapters reset completed.
choice /m "Would you like to restart your computer in 2 minutes? (Y/N)"
if errorlevel 2 goto MainMenu
if errorlevel 1 (
    echo Restarting in 2 minutes...
    shutdown /r /t 120 /c "Restarting to complete network adapter reset."
)
goto MainMenu

:ClearWSCache
echo Clearing Windows Store cache...
start /b wsreset.exe
echo Windows Store cache cleared. The Store will now open.
echo Press any key to return to menu...
pause >nul
goto MainMenu

:RepairWindowsUpdate
echo Repairing Windows Update...

net stop wuauserv
rd /s /q "%windir%\SoftwareDistribution"
net start wuauserv

echo Windows Update components have been reset.
echo Press any key to return to menu...
pause >nul
goto MainMenu

:CheckDisk
echo Running CHKDSK scan (read-only)...

set drive=%cd:~0,2%
chkdsk %drive% /scan

echo CHKDSK scan completed.
echo Press any key to return to menu...
pause >nul
goto MainMenu

:RestartExplorer
echo Restarting Windows Explorer...
taskkill /f /im explorer.exe
start explorer.exe
echo Windows Explorer restarted.
echo Press any key to return to menu...
pause >nul
goto MainMenu

:ClearBrowserCache
echo Clearing browser cache...
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255
echo Browser cache cleared.
echo Press any key to return to menu...
pause >nul
goto MainMenu

:ResetPrintQueue
echo Resetting Printer Queue...
net stop spooler
del /Q /F "%windir%\System32\spool\PRINTERS\*.*"
net start spooler
echo Printer queue has been reset.
echo Press any key to return to menu...
pause >nul
goto MainMenu

:RunSFC
echo Running System File Checker (SFC)...
sfc /scannow
echo SFC scan completed.
echo Press any key to return to menu...
pause >nul
goto MainMenu

:Exit
echo Exiting...
exit /b
