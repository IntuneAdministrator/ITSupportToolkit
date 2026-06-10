@echo off
:: ----------------------------------------
:: Microsoft 365 Repair Tool - Batch Menu
:: Requires Admin privileges
:: ----------------------------------------

:: Check for admin rights
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb runAs"
    exit /b
)

:: Set window title
title Microsoft 365 Repair

:MENU
cls
echo ==============================
echo   Microsoft 365 Repair Tool
echo ==============================
echo.
echo 1. Reset Outlook Views (/cleanviews)
echo 2. Reset Outlook Rules (/cleanrules)
echo 3. Run Office Quick Repair
echo 4. Run Office Full Repair
echo 5. Clean Microsoft Teams Cache
echo 6. Clean Outlook Cache
echo 7. Fix Office 365 Sign-In Loop
echo 0. Exit
echo.
set /p choice=Choose an option [0-7]:

if "%choice%"=="1" goto ResetViews
if "%choice%"=="2" goto ResetRules
if "%choice%"=="3" goto QuickRepair
if "%choice%"=="4" goto FullRepair
if "%choice%"=="5" goto CleanTeams
if "%choice%"=="6" goto CleanOutlookCache
if "%choice%"=="7" goto FixSignInLoop
if "%choice%"=="0" exit

echo Invalid choice, please try again.
pause
goto MENU

:ResetViews
call :RunOutlookCommand "/cleanviews" "Outlook Views Reset"
goto MENU

:ResetRules
call :RunOutlookCommand "/cleanrules" "Outlook Rules Reset"
goto MENU

:QuickRepair
call :RunOfficeRepair "QuickRepair"
goto MENU

:FullRepair
call :RunOfficeRepair "FullRepair"
goto MENU

:CleanTeams
call :CleanTeamsCache
goto MENU

:CleanOutlookCache
call :CleanOutlookCache
goto MENU

:FixSignInLoop
call :FixOfficeSignInLoop
goto MENU

:: ----------------------------------------
:: Functions
:: ----------------------------------------

:RunOutlookCommand
setlocal
set arg=%1
set operation=%2

echo Closing Outlook if running...
powershell -Command "Get-Process outlook -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }"
timeout /t 3 /nobreak >nul

echo Starting Outlook with %arg%...
call :FindOutlookPath outlookPath

if "%outlookPath%"=="" (
    echo Outlook.exe not found. Please ensure Outlook is installed.
    pause
    endlocal & exit /b
)

start "" "%outlookPath%" %arg%
echo %operation% initiated.
pause
endlocal
exit /b

:FindOutlookPath
setlocal
set "paths=%ProgramFiles%\Microsoft Office\root\Office16\OUTLOOK.EXE;%ProgramFiles(x86)%\Microsoft Office\root\Office16\OUTLOOK.EXE;%ProgramFiles%\Microsoft Office\Office16\OUTLOOK.EXE;%ProgramFiles(x86)%\Microsoft Office\Office16\OUTLOOK.EXE"
for %%P in (%paths%) do (
    if exist "%%~P" (
        endlocal & set %1=%%~P
        exit /b
    )
)
:: fallback to using where.exe
for /f "delims=" %%i in ('where outlook.exe 2^>nul') do (
    endlocal & set %1=%%i
    exit /b
)
endlocal & set %1=
exit /b

:RunOfficeRepair
setlocal
set repairType=%1

set "CTRPath=%ProgramFiles%\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
if not exist "%CTRPath%" (
    set "CTRPath=%ProgramFiles(x86)%\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
)

if not exist "%CTRPath%" (
    echo OfficeClickToRun.exe not found. Please verify Microsoft Office is installed.
    pause
    endlocal & exit /b
)

echo Starting Office %repairType% repair...
start "" "%CTRPath%" scenario=Repair platform=x64 culture=en-us forceappshutdown=True RepairType=%repairType% DisplayLevel=True
echo Repair process started. Please follow any prompts.
pause
endlocal
exit /b

:CleanTeamsCache
echo Stopping Teams processes...
powershell -Command "Get-Process -Name *teams* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue"
timeout /t 2 /nobreak >nul

echo Deleting Teams cache folders...
rd /s /q "%LOCALAPPDATA%\Packages\MSTeams_8wekyb3d8bbwe" 2>nul
rd /s /q "%APPDATA%\Microsoft\Teams" 2>nul

echo Teams cache cleaned.
pause
exit /b

:CleanOutlookCache
echo Closing Outlook processes...
powershell -Command "Get-Process -Name outlook -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue"
timeout /t 3 /nobreak >nul

echo Deleting Outlook cache folder...
rd /s /q "%LOCALAPPDATA%\Microsoft\Outlook" 2>nul

echo Outlook cache cleaned.
pause
exit /b

:FixOfficeSignInLoop
echo Fixing Office 365 Sign-In Loop...

powershell -Command ^
"try { ^
  $key='HKCU:\Software\Microsoft\Office\16.0\Common\Identity'; ^
  $props=Get-ItemProperty -Path $key; ^
  if ($props.EnableADAL -eq 0) { ^
    Set-ItemProperty -Path $key -Name EnableADAL -Value 1; ^
    Write-Output 'Modern Authentication (EnableADAL) was OFF. It has been ENABLED.`nPlease restart Office apps.'; ^
  } else { ^
    Write-Output 'Modern Authentication is already enabled. No action needed.'; ^
  } ^
} catch { ^
  Write-Output 'Registry key not found or error reading Office identity settings.'; ^
}"

pause
exit /b
