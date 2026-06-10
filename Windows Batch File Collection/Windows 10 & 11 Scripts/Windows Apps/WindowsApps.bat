@echo off
:: Check for admin rights
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title WindowsApps

:MENU
cls
echo =============================
echo    Windows Apps & Features
echo =============================
echo.
echo 1. Apps & Features
echo 2. Apps for websites
echo 3. Manage optional features
echo 4. Startup apps
echo 0. Exit
echo.

set /p choice=Select an option [0-4]: 

if "%choice%"=="1" goto AppsFeatures
if "%choice%"=="2" goto AppsForWebsites
if "%choice%"=="3" goto ManageOptionalFeatures
if "%choice%"=="4" goto StartupApps
if "%choice%"=="0" goto Exit

echo Invalid selection, please try again.
pause
goto MENU

:AppsFeatures
start ms-settings:appsfeatures
call :LogAction "Opened Apps & Features"
goto MENU

:AppsForWebsites
start ms-settings:appsforwebsites
call :LogAction "Opened Apps for websites"
goto MENU

:ManageOptionalFeatures
start ms-settings:optionalfeatures
call :LogAction "Opened Manage optional features"
goto MENU

:StartupApps
start ms-settings:startupapps
call :LogAction "Opened Startup apps"
goto MENU

:Exit
echo Goodbye!
exit /b

:: Log actions to Windows Event Log using PowerShell
:LogAction
setlocal
set msg=%~1
powershell -Command ^
 " $logName = 'Application';" ^
 " $source = 'BAT - WindowsApps Launcher';" ^
 " if (-not [System.Diagnostics.EventLog]::SourceExists($source)) { try { New-EventLog -LogName $logName -Source $source } catch { }; }" ^
 " Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message '%msg%';"
endlocal
exit /b
