@echo off
:: Check for admin rights
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title WindowsNetworkandInternet

:MENU
cls
echo ===============================
echo     Windows Network & Internet
echo ===============================
echo.
echo 1. Open Network & Internet Settings
echo 0. Exit
echo.

set /p choice=Select an option [0-1]: 

if "%choice%"=="1" goto NetworkInternet
if "%choice%"=="0" goto Exit

echo Invalid choice, please try again.
pause
goto MENU

:NetworkInternet
start ms-settings:network-status
call :LogAction "Opened Network & Internet settings"
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
 " $source = 'BAT - WindowsNetworkandInternet Launcher';" ^
 " if (-not [System.Diagnostics.EventLog]::SourceExists($source)) { try { New-EventLog -LogName $logName -Source $source } catch { }; }" ^
 " Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message '%msg%';"
endlocal
exit /b
