@echo off
:: Check for admin rights
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title WindowsDevices

:MENU
cls
echo ===============================
echo      Windows Device Settings
echo ===============================
echo.
echo 1. AutoPlay
echo 2. Bluetooth
echo 3. Connected Devices
echo 4. Default Camera
echo 5. USB
echo 6. Printers & Scanners
echo 7. Your Phone
echo 0. Exit
echo.

set /p choice=Select an option [0-7]: 

if "%choice%"=="1" goto AutoPlay
if "%choice%"=="2" goto Bluetooth
if "%choice%"=="3" goto ConnectedDevices
if "%choice%"=="4" goto DefaultCamera
if "%choice%"=="5" goto USB
if "%choice%"=="6" goto PrintersScanners
if "%choice%"=="7" goto YourPhone
if "%choice%"=="0" goto Exit

echo Invalid choice, please try again.
pause
goto MENU

:AutoPlay
start ms-settings:autoplay
call :LogAction "Opened AutoPlay settings"
goto MENU

:Bluetooth
start ms-settings:bluetooth
call :LogAction "Opened Bluetooth settings"
goto MENU

:ConnectedDevices
start ms-settings:connecteddevices
call :LogAction "Opened Connected Devices settings"
goto MENU

:DefaultCamera
start ms-settings:camera
call :LogAction "Opened Default Camera settings"
goto MENU

:USB
start ms-settings:usb
call :LogAction "Opened USB settings"
goto MENU

:PrintersScanners
start ms-settings:printers
call :LogAction "Opened Printers & Scanners settings"
goto MENU

:YourPhone
start ms-settings:mobile-devices
call :LogAction "Opened Your Phone settings"
goto MENU

:Exit
echo Exiting...
exit /b

:: Logs action to Windows Event Log via PowerShell
:LogAction
setlocal
set msg=%~1
powershell -Command ^
 " $logName = 'Application';" ^
 " $source = 'BAT - WindowsDevices Launcher';" ^
 " if (-not [System.Diagnostics.EventLog]::SourceExists($source)) { try { New-EventLog -LogName $logName -Source $source } catch { }; }" ^
 " Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message '%msg%';"
endlocal
exit /b
