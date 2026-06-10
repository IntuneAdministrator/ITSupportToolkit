@echo off
:: NetworkDiagnosticv0.2.bat
:: Simple network diagnostic menu with admin rights check

:: Set window title
title NetworkDiagnosticv0.2

:: Function to check for admin rights
:: If not admin, relaunch with admin
net session >nul 2>&1
if errorlevel 1 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ===========================================
echo      Network Diagnostic & Health Check
echo ===========================================
echo.
echo 1. Reset TCP/IP Stack
echo 2. Flush DNS Cache
echo 3. Release and Renew IP Address
echo 4. Restart Network Adapter(s)
echo 5. Ping Test (8.8.8.8)
echo 6. Show IP Configuration
echo 7. Exit
echo.
set /p choice=Enter your choice (1-7): 

if "%choice%"=="1" goto ResetTCPIP
if "%choice%"=="2" goto FlushDNS
if "%choice%"=="3" goto RenewIP
if "%choice%"=="4" goto RestartNIC
if "%choice%"=="5" goto PingTest
if "%choice%"=="6" goto ShowIPConfig
if "%choice%"=="7" goto Exit

echo Invalid choice. Please try again.
pause
goto MENU

:ResetTCPIP
echo Resetting TCP/IP stack...
netsh int ip reset
if errorlevel 1 (
    echo Failed to reset TCP/IP stack.
) else (
    echo TCP/IP stack reset successfully.
)
pause
goto MENU

:FlushDNS
echo Flushing DNS cache...
ipconfig /flushdns
if errorlevel 1 (
    echo Failed to flush DNS cache.
) else (
    echo DNS cache flushed successfully.
)
pause
goto MENU

:RenewIP
echo Releasing IP address...
ipconfig /release
echo Renewing IP address...
ipconfig /renew
if errorlevel 1 (
    echo Failed to renew IP address.
) else (
    echo IP address renewed successfully.
)
pause
goto MENU

:RestartNIC
echo Restarting network adapter(s)...
:: List adapters
echo Listing active network adapters...
for /f "tokens=2 delims=:" %%A in ('netsh interface show interface ^| findstr /C:"Connected"') do (
    set "adapter=%%A"
    call :Trim adapter
    echo Restarting adapter: %adapter%
    netsh interface set interface name="%adapter%" admin=disable
    timeout /t 2 >nul
    netsh interface set interface name="%adapter%" admin=enable
    timeout /t 2 >nul
)
echo Network adapter(s) restarted successfully.
pause
goto MENU

:: Helper function to trim spaces from variable
:Trim
setlocal enabledelayedexpansion
set "str=!%1!"
for /f "tokens=* delims= " %%a in ("!str!") do set "str=%%a"
endlocal & set "%1=%str%"
goto :eof

:PingTest
echo Performing ping test to 8.8.8.8...
ping 8.8.8.8 -n 4
pause
goto MENU

:ShowIPConfig
echo Showing IP configuration...
ipconfig /all
pause
goto MENU

:Exit
echo Exiting. Goodbye!
exit /b
