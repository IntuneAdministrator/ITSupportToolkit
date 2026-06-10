@echo off
:: Check for admin rights
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title WindowsPersonalization

:MENU
cls
echo ===============================
echo      Windows Personalization
echo ===============================
echo.
echo 1. Background
echo 2. Choose Folders on Start
echo 3. Lock Screen
echo 4. Themes
echo 0. Exit
echo.

set /p choice=Select an option [0-4]: 

if "%choice%"=="1" goto Background
if "%choice%"=="2" goto StartFolders
if "%choice%"=="3" goto LockScreen
if "%choice%"=="4" goto Themes
if "%choice%"=="0" goto Exit

echo Invalid choice, please try again.
pause
goto MENU

:Background
start ms-settings:personalization-background
call :LogAction "Opened Background settings"
goto MENU

:StartFolders
start ms-settings:personalization-start-places
call :LogAction "Opened Choose Folders on Start settings"
goto MENU

:LockScreen
start ms-settings:lockscreen
call :LogAction "Opened Lock Screen settings"
goto MENU

:Themes
start ms-settings:themes
call :LogAction "Opened Themes settings"
goto MENU

:Exit
echo Exiting...
exit /b

:: Log action to Windows Event Log via PowerShell
:LogAction
setlocal
set msg=%~1
powershell -Command ^
 " $logName = 'Application';" ^
 " $source = 'BAT - WindowsPersonalization Launcher';" ^
 " if (-not [System.Diagnostics.EventLog]::SourceExists($source)) { try { New-EventLog -LogName $logName -Source $source } catch { }; }" ^
 " Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message '%msg%';"
endlocal
exit /b
