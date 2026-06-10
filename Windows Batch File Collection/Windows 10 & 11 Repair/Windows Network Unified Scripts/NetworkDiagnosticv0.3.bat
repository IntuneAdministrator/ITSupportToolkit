@echo off
:: NetworkDiagnosticv0.3.bat
:: Network Diagnostic and Health Check Tool (batch version)

title NetworkDiagnosticv0.3

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
echo      Network Diagnostic & Health Check v0.3
echo ===========================================
echo.
echo 1. Reset Windows Firewall to Default
echo 2. Reset Winsock Catalog
echo 3. Repair Network Adapter Driver
echo 4. Clear Wi-Fi Profiles (Deletes all saved Wi-Fi profiles)
echo 5. Exit
echo.
set /p choice=Enter your choice (1-5): 

if "%choice%"=="1" goto ResetFirewall
if "%choice%"=="2" goto ResetWinsock
if "%choice%"=="3" goto RepairNICDriver
if "%choice%"=="4" goto ClearWiFiProfiles
if "%choice%"=="5" goto Exit

echo Invalid choice. Please try again.
pause
goto MENU

:ResetFirewall
echo Resetting Windows Firewall to default...
netsh advfirewall reset
if errorlevel 1 (
    echo Failed to reset Windows Firewall.
) else (
    echo Windows Firewall reset successfully.
)
pause
goto MENU

:ResetWinsock
echo Resetting Winsock Catalog...
netsh winsock reset
if errorlevel 1 (
    echo Failed to reset Winsock catalog.
) else (
    echo Winsock reset complete. Reboot is recommended.
)
pause
goto MENU

:RepairNICDriver
echo Repairing Network Adapter Drivers...
echo Disabling active network adapters...
for /f "tokens=2 delims=:" %%a in ('netsh interface show interface ^| findstr /R /C:"Connected"') do (
    set "adapter=%%a"
    call :Trim adapter
    echo Disabling adapter: %adapter%
    netsh interface set interface name="%adapter%" admin=disable
)
timeout /t 3 >nul
echo Enabling previously disabled network adapters...
for /f "tokens=2 delims=:" %%a in ('netsh interface show interface ^| findstr /R /C:"Disabled"') do (
    set "adapter=%%a"
    call :Trim adapter
    echo Enabling adapter: %adapter%
    netsh interface set interface name="%adapter%" admin=enable
)
echo Network adapter repair complete.
pause
goto MENU

:ClearWiFiProfiles
echo WARNING: This will delete all saved Wi-Fi profiles and passwords.
echo You will need to reconnect and enter passwords manually.
echo.
set /p confirm=Are you sure you want to continue? (Y/N): 
if /i "%confirm%" NEQ "Y" (
    echo Operation cancelled.
    pause
    goto MENU
)
echo Clearing all Wi-Fi profiles...
netsh wlan delete profile name=*
if errorlevel 1 (
    echo Failed to clear Wi-Fi profiles.
) else (
    echo All Wi-Fi profiles cleared successfully.
)
pause
goto MENU

:Exit
echo Exiting. Goodbye!
exit /b

:: Helper to trim leading/trailing spaces from a variable
:Trim
setlocal enabledelayedexpansion
set "str=!%1!"
for /f "tokens=* delims= " %%a in ("!str!") do set "str=%%a"
for /l %%i in (1,1,31) do if "!str:~-1!"==" " set "str=!str:~0,-1!"
endlocal & set "%1=%str%"
goto :eof
