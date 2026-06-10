@echo off
:: Require admin rights
:: Check if admin
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title WindowsAccounts

:MENU
cls
echo ===============================
echo       Windows Account Settings
echo ===============================
echo.
echo 1. Access work or school
echo 2. Email & app accounts
echo 3. Family & other people
echo 4. Repair token
echo 5. Set up a kiosk
echo 6. Sign-in options
echo 7. Sign-in options - Dynamic Lock
echo 8. Sync your settings
echo 9. Windows Backup
echo 10. Windows Hello setup - Face enrollment
echo 11. Windows Hello setup - Fingerprint enrollment
echo 12. Your info
echo 0. Exit
echo.

set /p choice=Select an option [0-12]: 

if "%choice%"=="1" goto AccessWorkSchool
if "%choice%"=="2" goto EmailAppAccounts
if "%choice%"=="3" goto FamilyOtherPeople
if "%choice%"=="4" goto RepairToken
if "%choice%"=="5" goto SetupKiosk
if "%choice%"=="6" goto SigninOptions
if "%choice%"=="7" goto SigninOptionsDynamicLock
if "%choice%"=="8" goto SyncSettings
if "%choice%"=="9" goto Backup
if "%choice%"=="10" goto WindowsHelloFace
if "%choice%"=="11" goto WindowsHelloFingerprint
if "%choice%"=="12" goto YourInfo
if "%choice%"=="0" goto Exit

echo Invalid option, try again.
pause
goto MENU

:: Define each label to launch ms-settings and log the action

:AccessWorkSchool
start ms-settings:workplace
call :LogAction "Opened 'Access work or school'"
goto MENU

:EmailAppAccounts
start ms-settings:emailandaccounts
call :LogAction "Opened 'Email & app accounts'"
goto MENU

:FamilyOtherPeople
start ms-settings:otherusers
call :LogAction "Opened 'Family & other people'"
goto MENU

:RepairToken
start ms-settings:workplace-repairtoken
call :LogAction "Opened 'Repair token'"
goto MENU

:SetupKiosk
start ms-settings:assignedaccess
call :LogAction "Opened 'Set up a kiosk'"
goto MENU

:SigninOptions
start ms-settings:signinoptions
call :LogAction "Opened 'Sign-in options'"
goto MENU

:SigninOptionsDynamicLock
start ms-settings:signinoptions-dynamiclock
call :LogAction "Opened 'Dynamic Lock'"
goto MENU

:SyncSettings
start ms-settings:sync
call :LogAction "Opened 'Sync your settings'"
goto MENU

:Backup
start ms-settings:backup
call :LogAction "Opened 'Backup'"
goto MENU

:WindowsHelloFace
start ms-settings:signinoptions-launchfaceenrollment
call :LogAction "Opened 'Face enrollment'"
goto MENU

:WindowsHelloFingerprint
start ms-settings:signinoptions-launchfingerprintenrollment
call :LogAction "Opened 'Fingerprint enrollment'"
goto MENU

:YourInfo
start ms-settings:yourinfo
call :LogAction "Opened 'Your info'"
goto MENU

:Exit
echo Goodbye!
exit /b

:: Subroutine to log actions using PowerShell
:LogAction
setlocal
set msg=%~1
powershell -Command ^
 " $logName = 'Application';" ^
 " $source = 'BAT - WindowsAccounts Launcher';" ^
 " if (-not [System.Diagnostics.EventLog]::SourceExists($source)) { try { New-EventLog -LogName $logName -Source $source } catch { }; }" ^
 " Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message '%msg%';"
endlocal
exit /b
