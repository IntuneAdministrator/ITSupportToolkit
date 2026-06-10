@echo off
:: Request admin rights if not elevated
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title WindowsSystem

:MENU
cls
echo =============================
echo      Windows System Settings
echo =============================
echo.
echo 1. About
echo 2. Display
echo 3. Power & Sleep
echo 0. Exit
echo.

set /p choice=Select an option [0-3]: 

if "%choice%"=="1" goto About
if "%choice%"=="2" goto Display
if "%choice%"=="3" goto PowerSleep
if "%choice%"=="0" goto Exit

echo Invalid choice. Please try again.
pause
goto MENU

:About
start ms-settings:about
call :LogAction "Opened About system settings"
goto MENU

:Display
start ms-settings:display
call :LogAction "Opened Display system settings"
goto MENU

:PowerSleep
start ms-settings:powersleep
call :LogAction "Opened Power & Sleep system settings"
goto MENU

:Exit
echo Exiting...
exit /b

:: Log actions to Windows Event Log under a custom source
:LogAction
setlocal
set "msg=%~1"
powershell -Command ^
 " $logName = 'Application';" ^
 " $source = 'BAT - WindowsSystem Launcher';" ^
 " if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {" ^
 "   try { New-EventLog -LogName $logName -Source $source } catch {} }" ^
 " Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message '%msg%';"
endlocal
exit /b
