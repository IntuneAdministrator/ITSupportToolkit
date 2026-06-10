@echo off
title SystemInfoScanner v0.2
color 0A

:MENU
cls
echo ================================
echo    SystemInfoScanner v0.2
echo ================================
echo.
echo 1. System Info
echo 2. Disk Space
echo 3. BitLocker Status
echo 4. Recent Windows Updates
echo 5. Critical Services Status
echo 6. Network Info
echo 7. CPU & Memory Usage
echo 8. Logged-in Users
echo 9. Top Memory Processes
echo 10. Pending Reboot Check
echo 11. Firewall Status
echo 12. Recent System Errors
echo 13. Battery Status
echo 14. Quick Malware Scan
echo 15. Disk Health (SMART)
echo 16. System Uptime
echo 17. Windows Defender Status
echo 18. System Temperature
echo 0. Exit
echo.
set /p choice=Choose an option:

REM Run the selected option
if "%choice%"=="1" goto SystemInfo
if "%choice%"=="2" goto DiskSpace
if "%choice%"=="3" goto BitLocker
if "%choice%"=="4" goto Updates
if "%choice%"=="5" goto Services
if "%choice%"=="6" goto NetworkInfo
if "%choice%"=="7" goto CpuMem
if "%choice%"=="8" goto Users
if "%choice%"=="9" goto TopProcesses
if "%choice%"=="10" goto PendingReboot
if "%choice%"=="11" goto Firewall
if "%choice%"=="12" goto EventLogs
if "%choice%"=="13" goto Battery
if "%choice%"=="14" goto MalwareScan
if "%choice%"=="15" goto DiskHealth
if "%choice%"=="16" goto Uptime
if "%choice%"=="17" goto Defender
if "%choice%"=="18" goto Temperature
if "%choice%"=="0" exit

echo Invalid choice, try again.
pause
goto MENU

:SystemInfo
cls
echo === SYSTEM INFO ===
powershell -command "Get-ComputerInfo | Select-Object OSName, CsSystemType, WindowsVersion, WindowsBuildLabEx | Format-List"
pause
goto MENU

:DiskSpace
cls
echo === DISK SPACE ===
powershell -command "Get-PSDrive -PSProvider FileSystem | ForEach-Object {Write-Output ('{0}: {1:N2} GB free of {2:N2} GB' -f $_.Name, ($_.Free/1GB), ($_.Used/1GB + $_.Free/1GB))}"
pause
goto MENU

:BitLocker
cls
echo === BITLOCKER STATUS ===
powershell -command "try {Get-BitLockerVolume | ForEach-Object { '{0}: {1}' -f $_.MountPoint, $_.ProtectionStatus }} catch {Write-Output 'BitLocker not enabled or unavailable.'}"
pause
goto MENU

:Updates
cls
echo === RECENT WINDOWS UPDATES ===
powershell -command "Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5 | Format-Table InstalledOn, HotFixID -AutoSize"
pause
goto MENU

:Services
cls
echo === CRITICAL SERVICES ===
powershell -command "Get-Service -Name spooler, wuauserv, WinDefend | Format-Table DisplayName, Status -AutoSize"
pause
goto MENU

:NetworkInfo
cls
echo === NETWORK INFO ===
powershell -command "$net = Get-NetIPConfiguration | Select-Object -First 1; if ($net) { Write-Output ('IPv4: {0}' -f $net.IPv4Address.IPAddress); Write-Output ('Gateway: {0}' -f $net.IPv4DefaultGateway.NextHop); Write-Output ('DNS: {0}' -f ($net.DNSServer.ServerAddresses -join ', '))} else { Write-Output 'Network info unavailable.' }"
pause
goto MENU

:CpuMem
cls
echo === CPU & MEMORY USAGE ===
powershell -command "$cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue; $ram = Get-CimInstance Win32_OperatingSystem; $totalMem = [math]::Round($ram.TotalVisibleMemorySize / 1MB, 2); $freeMem = [math]::Round($ram.FreePhysicalMemory / 1MB, 2); $usedMem = [math]::Round($totalMem - $freeMem, 2); Write-Output ('CPU Usage: {0:N1}%%' -f $cpu); Write-Output ('RAM Usage: {0} GB / {1} GB' -f $usedMem, $totalMem)"
pause
goto MENU

:Users
cls
echo === LOGGED-IN USERS ===
quser
pause
goto MENU

:TopProcesses
cls
echo === TOP MEMORY PROCESSES ===
powershell -command "Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5 | ForEach-Object { '{0}: {1:N1} MB' -f $_.Name, ($_.WorkingSet / 1MB) }"
pause
goto MENU

:PendingReboot
cls
echo === PENDING REBOOT CHECK ===
powershell -command "if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { Write-Output 'A reboot is pending.' } else { Write-Output 'No pending reboot detected.' }"
pause
goto MENU

:Firewall
cls
echo === FIREWALL STATUS ===
powershell -command "Get-NetFirewallProfile -Profile Domain,Public,Private | ForEach-Object { '{0}: {1}' -f $_.Name, (if ($_.Enabled) {'Enabled'} else {'Disabled'}) }"
pause
goto MENU

:EventLogs
cls
echo === RECENT SYSTEM ERRORS ===
powershell -command "Get-WinEvent -FilterHashtable @{LogName='System'; Level=2} -MaxEvents 5 | ForEach-Object { '{0}: {1}' -f $_.TimeCreated, $_.Message }"
pause
goto MENU

:Battery
cls
echo === BATTERY STATUS ===
powershell -command "$battery = Get-WmiObject -Class Win32_Battery; if ($battery -eq $null) {Write-Output 'No battery detected.'} else { $status = if ($battery.BatteryStatus -eq 2) {'Charging'} else {'Discharging'}; Write-Output ('Status: {0}' -f $status); Write-Output ('Charge Remaining: {0}%%' -f $battery.EstimatedChargeRemaining) }"
pause
goto MENU

:MalwareScan
cls
echo === QUICK MALWARE SCAN ===
powershell -command "$malware = Get-Process | Where-Object { $_.Name -match 'malware|trojan|virus' }; if ($malware.Count -gt 0) { $malware | ForEach-Object { Write-Output ('{0} (PID: {1})' -f $_.Name, $_.Id) } } else { Write-Output 'No malware-related processes detected.' }"
pause
goto MENU

:DiskHealth
cls
echo === DISK HEALTH (SMART) ===
powershell -command "Get-WmiObject -Class Win32_DiskDrive | ForEach-Object { '{0}: {1}' -f $_.DeviceID, $_.Status }"
pause
goto MENU

:Uptime
cls
echo === SYSTEM UPTIME ===
powershell -command "$uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime; Write-Output ('{0} days, {1} hours, {2} minutes' -f $uptime.Days, $uptime.Hours, $uptime.Minutes)"
pause
goto MENU

:Defender
cls
echo === WINDOWS DEFENDER STATUS ===
powershell -command "$status = Get-MpComputerStatus; Write-Output ('Real-time protection: {0}' -f $status.RealTimeProtectionEnabled); Write-Output ('Virus Signature Last Updated: {0}' -f $status.AntivirusSignatureLastUpdated)"
pause
goto MENU

:Temperature
cls
echo === SYSTEM TEMPERATURE ===
powershell -command "try { $temp = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue; if ($temp) { $celsius = [math]::Round(($temp.CurrentTemperature - 2732) / 10, 2); Write-Output ('CPU Temperature: {0} °C' -f $celsius) } else { Write-Output 'No temperature data available.' } } catch { Write-Output ('Error retrieving temperature: {0}' -f $_) }"
pause
goto MENU
