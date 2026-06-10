@echo off
title NetworkDiagnosticv0.1

:: Check for admin rights by trying to write to a protected directory
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo.
    echo *** Administrator privileges are required to run this tool. ***
    echo Running as administrator...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ================================
echo      Network Diagnostic v0.1
echo ================================
echo 1. Set DNS Servers (Google DNS)
echo 2. Show Network Info
echo 3. Restart Network Adapters
echo 4. Set Speed & Duplex (1.0 Gbps Full Duplex)
echo 5. Reset Network Configuration
echo 6. Exit
echo ================================
set /p choice=Choose an option (1-6): 

if "%choice%"=="1" goto SetDNS
if "%choice%"=="2" goto ShowInfo
if "%choice%"=="3" goto RestartAdapters
if "%choice%"=="4" goto SetSpeedDuplex
if "%choice%"=="5" goto ResetNetwork
if "%choice%"=="6" goto Exit
echo Invalid option. Please try again.
pause
goto MENU

:SetDNS
echo Setting DNS Servers to Google DNS (8.8.8.8, 8.8.4.4)...
for /f "tokens=1 delims=:" %%a in ('netsh interface show interface ^| findstr /R /C:"Connected"') do (
    set "adapter=%%a"
    setlocal enabledelayedexpansion
    set "adapter=!adapter:~1!"
    echo Setting DNS on adapter "!adapter!"
    netsh interface ip set dns name="!adapter!" static 8.8.8.8 primary >nul 2>&1
    netsh interface ip add dns name="!adapter!" 8.8.4.4 index=2 >nul 2>&1
    endlocal
)
echo DNS servers set.
pause
goto MENU

:ShowInfo
echo Gathering network adapter information...
echo.
ipconfig /all
echo.
pause
goto MENU

:RestartAdapters
echo Restarting network adapters...
for /f "tokens=1 delims=:" %%a in ('netsh interface show interface ^| findstr /R /C:"Connected"') do (
    set "adapter=%%a"
    setlocal enabledelayedexpansion
    set "adapter=!adapter:~1!"
    echo Disabling adapter "!adapter!"...
    netsh interface set interface name="!adapter!" admin=disable >nul 2>&1
    timeout /t 2 >nul
    echo Enabling adapter "!adapter!"...
    netsh interface set interface name="!adapter!" admin=enable >nul 2>&1
    endlocal
)
echo Network adapters restarted.
pause
goto MENU

:SetSpeedDuplex
echo Setting Speed & Duplex to 1.0 Gbps Full Duplex is not supported via batch.
echo Please configure manually in the adapter properties or use PowerShell script.
echo Alternatively, run the PowerShell version of this tool.
pause
goto MENU

:ResetNetwork
echo Resetting network configuration...
echo Releasing IP...
ipconfig /release
timeout /t 2 >nul
echo Renewing IP...
ipconfig /renew
timeout /t 2 >nul
echo Flushing DNS cache...
ipconfig /flushdns
echo Resetting Winsock...
netsh winsock reset
echo Resetting TCP/IP stack...
netsh int ip reset
echo.
echo Network reset complete. Please restart your computer.
pause
goto MENU

:Exit
exit
