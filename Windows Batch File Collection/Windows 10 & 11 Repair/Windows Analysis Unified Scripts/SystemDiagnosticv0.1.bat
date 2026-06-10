@echo off
title SystemDiagnostic v0.1

:: Check for admin rights by trying to write to a system folder
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo [!] Administrative privileges required. Relaunching as administrator...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cls
echo =============================================
echo      System Diagnostic & Health Check v0.1
echo =============================================
echo.

:menu
echo Choose an option:
echo 1. Battery & BIOS Scan
echo 2. Scan Last BSOD Event
echo 3. Show BIOS Information
echo 4. Show System Info
echo 5. Check OS End-of-Life Status
echo 6. Internet Connectivity Test
echo 7. Show System Uptime
echo 8. Start System Health Check
echo 9. Exit
echo.
set /p choice=Enter your choice (1-9): 

if "%choice%"=="1" goto battery_bios_scan
if "%choice%"=="2" goto bsod_scan
if "%choice%"=="3" goto show_bios_info
if "%choice%"=="4" goto show_system_info
if "%choice%"=="5" goto check_os_eol
if "%choice%"=="6" goto internet_test
if "%choice%"=="7" goto show_uptime
if "%choice%"=="8" goto health_check
if "%choice%"=="9" goto exit_script

echo Invalid choice. Try again.
echo.
goto menu

:: ---------------------------------------------------
:battery_bios_scan
cls
echo Running Battery & BIOS Scan...
echo.

:: Battery check (simple)
powercfg /batteryreport >nul 2>&1
if %errorlevel%==0 (
    echo Battery report generated if applicable.
) else (
    echo No battery detected or failed to generate battery report.
)

:: BIOS info (limited in batch)
echo Retrieving BIOS information...
wmic bios get serialnumber, version, manufacturer
echo.

pause
goto menu

:: ---------------------------------------------------
:bsod_scan
cls
echo Scanning last BSOD event (if any)...
echo.

:: BSOD info from event logs
wevtutil qe System /q:"*[System[(EventID=1001)]]" /f:text /c:5 > bsod.txt 2>nul
if %errorlevel% neq 0 (
    echo Failed to retrieve BSOD events.
) else (
    findstr /i "BugCheckCode" bsod.txt >nul
    if %errorlevel%==0 (
        echo Recent BSOD events found:
        type bsod.txt
    ) else (
        echo No recent BSOD events found.
    )
)
del bsod.txt 2>nul
echo.
pause
goto menu

:: ---------------------------------------------------
:show_bios_info
cls
echo BIOS Information:
wmic bios get /format:list
echo.
pause
goto menu

:: ---------------------------------------------------
:show_system_info
cls
echo System Information:
systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"System Manufacturer" /C:"System Model" /C:"Processor" /C:"Total Physical Memory"
echo.
pause
goto menu

:: ---------------------------------------------------
:check_os_eol
cls
echo Checking OS End-of-Life Status...
echo.

:: Get OS version and approximate EOL check (simplified)
for /f "tokens=2 delims==" %%a in ('wmic os get version /value ^| find "="') do set osver=%%a
echo OS Version: %osver%

:: Basic EOL check for common versions (example)
if "%osver:~0,5%"=="10.0." (
    echo Assuming Windows 10 or 11. Check official Microsoft EOL dates manually.
) else (
    echo OS version not recognized for automatic EOL check.
)
echo.
pause
goto menu

:: ---------------------------------------------------
:internet_test
cls
echo Running Internet Connectivity Test...
echo Pinging google.com 10 times...
ping -n 10 google.com
echo.
pause
goto menu

:: ---------------------------------------------------
:show_uptime
cls
echo Showing System Uptime...
for /f "tokens=1,2 delims=," %%a in ('systeminfo ^| find "System Boot Time"') do set bootTime=%%b
if defined bootTime (
    echo System Boot Time: %bootTime%
) else (
    echo Could not retrieve system boot time.
)
echo.
pause
goto menu

:: ---------------------------------------------------
:health_check
cls
echo Running System Health Check...
echo.

:: CPU usage approx with WMIC (not real-time)
wmic cpu get loadpercentage

:: Memory usage (simple)
for /f "tokens=2 delims==" %%a in ('wmic os get FreePhysicalMemory /value') do set freeMem=%%a
for /f "tokens=2 delims==" %%a in ('wmic os get TotalVisibleMemorySize /value') do set totalMem=%%a

set /a usedMem=%totalMem% - %freeMem%
set /a memPercent=(%usedMem%*100)/%totalMem%
echo Memory Usage: %memPercent%%

:: Disk usage for C: drive
for /f "tokens=2 delims==" %%a in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value') do set freeSpace=%%a
for /f "tokens=2 delims==" %%a in ('wmic logicaldisk where "DeviceID='C:'" get Size /value') do set totalSpace=%%a

set /a usedSpace=%totalSpace% - %freeSpace%
set /a diskPercent=(%usedSpace%*100)/%totalSpace%
echo Disk C: Usage: %diskPercent%%

echo.
pause
goto menu

:: ---------------------------------------------------
:exit_script
cls
echo Exiting System Diagnostic Tool. Goodbye!
timeout /t 2 /nobreak >nul
exit /b
