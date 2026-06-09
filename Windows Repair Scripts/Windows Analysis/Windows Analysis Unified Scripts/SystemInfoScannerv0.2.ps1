<#
.SYNOPSIS
    A graphical system diagnostic and health check tool that provides essential system information and status checks.

.DESCRIPTION
    This script provides a comprehensive set of system diagnostic tools through a graphical user interface (GUI) built using Windows Presentation Foundation (WPF) and WinForms. 
    The tool allows the user to check various system metrics, including:
    - System information
    - Disk space usage
    - CPU and memory utilization
    - Windows updates
    - Service status
    - BitLocker encryption status
    - Network information
    - Battery status (if applicable)
    - Malware scan (basic)
    - Disk health (SMART)
    - Firewall status
    - Event logs and more.
    The tool uses a set of PowerShell cmdlets to gather data and presents the information in a user-friendly interface. It also includes features like system uptime, temperature reading (if supported), and quick access to recent system errors.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2  
    Requirements : 
        - Administrator rights are required to run this script with elevated privileges.
        - Outlook must be installed for certain network or email-related tasks (if planned for future versions).
        - .NET Framework 4.8 or later must be installed for WPF and WinForms components to function properly.
    Known Issues  : 
        - May not work properly on non-Windows OS or older Windows versions that don't support WPF.
        - Some cmdlets might require specific permissions or availability of hardware (e.g., battery-related checks only work on laptops).
    Change Log    : 
        - Version 1.0: Initial release of the tool with basic system diagnostics.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# XAML layout (updated buttons)
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="System Diagnostic &amp; Health Check Tool v0.2"
        Height="550" Width="520"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Background="#f4f4f4"
        FontFamily="Segoe UI"
        FontSize="12"
        SizeToContent="WidthAndHeight">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#f4f4f4"/>
            <Setter Property="Foreground" Value="Black"/>
            <Setter Property="BorderBrush" Value="#cccccc"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Width" Value="200"/>
            <Setter Property="Height" Value="20"/>
            <Setter Property="Margin" Value="5"/>
        </Style>
    </Window.Resources>

    <StackPanel Margin="20" HorizontalAlignment="Center">
        <TextBlock Text="System Diagnostic &amp; Health Check Tool v0.2" FontSize="16" FontWeight="Bold" Margin="0,0,0,20"
                   HorizontalAlignment="Center"/>
        <WrapPanel HorizontalAlignment="Center" Margin="0,0,0,10">
            <Button x:Name="SystemInfoBtn" Content="System Info"/>
            <Button x:Name="DiskSpaceBtn" Content="Disk Space"/>
            <Button x:Name="BitLockerBtn" Content="BitLocker"/>
        </WrapPanel>
        <WrapPanel HorizontalAlignment="Center" Margin="0,0,0,10">
            <Button x:Name="UpdatesBtn" Content="Updates"/>
            <Button x:Name="ServicesBtn" Content="Services"/>
            <Button x:Name="NetworkInfoBtn" Content="Network Info"/>
        </WrapPanel>
        <WrapPanel HorizontalAlignment="Center" Margin="0,0,0,10">
            <Button x:Name="CpuMemBtn" Content="CPU &amp; Memory"/>
            <Button x:Name="UsersBtn" Content="Users"/>
            <Button x:Name="TopProcBtn" Content="Top Processes"/>
        </WrapPanel>
        <WrapPanel HorizontalAlignment="Center" Margin="0,0,0,10">
            <Button x:Name="PendingRebootBtn" Content="Pending Reboot"/>
            <Button x:Name="FirewallBtn" Content="Firewall Status"/>
            <Button x:Name="EventLogsBtn" Content="Event Logs"/>
        </WrapPanel>
        <WrapPanel HorizontalAlignment="Center" Margin="0,0,0,10">
            <Button x:Name="BatteryBtn" Content="Battery Status"/>
            <Button x:Name="MalwareScanBtn" Content="Quick Malware Scan"/>
            <Button x:Name="DiskHealthBtn" Content="Disk Health (SMART)"/>
        </WrapPanel>
        <WrapPanel HorizontalAlignment="Center" Margin="0,0,0,10">
            <Button x:Name="UptimeBtn" Content="System Uptime"/>
            <Button x:Name="DefenderBtn" Content="Defender Status"/>
            <Button x:Name="TempBtn" Content="System Temperature"/>
        </WrapPanel>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="460" Minimum="0" Maximum="100" Margin="0,5,0,5" Value="0"/>
        <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="black" HorizontalAlignment="Center"/>
        <TextBlock Text=" Allester Padovani, Senior IT Specialist. All rights reserved." FontSize="12" FontStyle="Italic" Foreground="black" Margin="0,20,0,0" HorizontalAlignment="Center"/>
    </StackPanel>
</Window>
"@

# Load the XAML UI
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get UI Elements
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

function Animate-ProgressBar {
    param([int]$delay = 10)
    for ($i = 0; $i -le 100; $i += 5) {
        $ProgressBar.Value = $i
        $StatusText.Text = "Working... $i%"
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds $delay
    }
    $ProgressBar.Value = 0
    $StatusText.Text = "Ready."
}

function Show-Result {
    param([string]$title, [string]$message)
    [System.Windows.MessageBox]::Show($message, $title, 'OK', 'Information') | Out-Null
}

# Hook Button Events

# System Info Button
$window.FindName("SystemInfoBtn").Add_Click({
    Animate-ProgressBar
    $info = Get-ComputerInfo | Select-Object OSName, CsSystemType, WindowsVersion, WindowsBuildLabEx
    $msg = "=== SYSTEM INFO ===`nOS: $($info.OSName)`nSystem Type: $($info.CsSystemType)`nVersion: $($info.WindowsVersion)`nBuild: $($info.WindowsBuildLabEx)"
    Show-Result "System Info" $msg
})

# Disk Space Button
$window.FindName("DiskSpaceBtn").Add_Click({
    Animate-ProgressBar
    $msg = "=== DISK SPACE ===`n"
    foreach ($d in Get-PSDrive -PSProvider FileSystem) {
        $used = [math]::Round($d.Used / 1GB, 2)
        $total = [math]::Round($d.Size / 1GB, 2)
        $msg += "$($d.Name): $used GB used / $total GB total`n"
    }
    Show-Result "Disk Space" $msg
})

# BitLocker Button
$window.FindName("BitLockerBtn").Add_Click({
    Animate-ProgressBar
    $msg = "=== BITLOCKER STATUS ===`n"
    try {
        $bitlockerVolumes = Get-BitLockerVolume
        foreach ($vol in $bitlockerVolumes) {
            $msg += "$($vol.MountPoint): $($vol.ProtectionStatus)`n"
        }
    } catch {
        $msg = "BitLocker is not enabled or unavailable on this system."
    }
    Show-Result "BitLocker" $msg
})

# Updates Button
$window.FindName("UpdatesBtn").Add_Click({
    Animate-ProgressBar
    $updates = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5
    $msg = "=== RECENT UPDATES ===`n"
    foreach ($u in $updates) {
        $msg += "$($u.InstalledOn.ToShortDateString()): $($u.HotFixID)`n"
    }
    # Additional updates via Windows Update Service
    try {
        $windowsUpdates = Get-WmiObject -Class "Win32_QuickFixEngineering" | Sort-Object InstalledOn -Descending | Select-Object -First 5
        foreach ($update in $windowsUpdates) {
            $msg += "$($update.InstalledOn.ToShortDateString()): $($update.HotFixID)`n"
        }
    } catch {
        $msg += "`nAdditional updates could not be fetched."
    }
    Show-Result "Windows Updates" $msg
})

# Services Button
$window.FindName("ServicesBtn").Add_Click({
    Animate-ProgressBar
    $msg = "=== CRITICAL SERVICES ===`n"
    $services = Get-Service -Name spooler, wuauserv, WinDefend
    foreach ($s in $services) {
        $msg += "$($s.DisplayName): $($s.Status)`n"
    }
    Show-Result "Services" $msg
})

# Network Info Button
$window.FindName("NetworkInfoBtn").Add_Click({
    Animate-ProgressBar
    $net = Get-NetIPConfiguration | Select-Object -First 1
    $msg = "=== NETWORK INFO ===`n"
    if ($net) {
        $msg += "IPv4: $($net.IPv4Address.IPAddress)`n"
        $msg += "Gateway: $($net.IPv4DefaultGateway.NextHop)`n"
        $msg += "DNS: $($net.DNSServer.ServerAddresses -join ', ')"
    } else {
        $msg = "Network information could not be fetched."
    }
    Show-Result "Network Info" $msg
})

# CPU & Memory Button
$window.FindName("CpuMemBtn").Add_Click({
    Animate-ProgressBar
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
    $ram = Get-CimInstance Win32_OperatingSystem
    $totalMem = [math]::Round($ram.TotalVisibleMemorySize / 1MB, 2)
    $freeMem = [math]::Round($ram.FreePhysicalMemory / 1MB, 2)
    $usedMem = [math]::Round($totalMem - $freeMem, 2)
    $msg = "=== SYSTEM PERFORMANCE ===`nCPU Usage: {0:N1}%%`nRAM: $usedMem GB / $totalMem GB" -f $cpu
    Show-Result "Performance Snapshot" $msg
})

# Users Button
$window.FindName("UsersBtn").Add_Click({
    Animate-ProgressBar
    $users = quser
    $msg = "=== LOGGED-IN USERS ===`n$users"
    Show-Result "User Sessions" $msg
})

# Top Processes Button
$window.FindName("TopProcBtn").Add_Click({
    Animate-ProgressBar
    $msg = "=== TOP MEMORY PROCESSES ===`n"
    $procs = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5
    foreach ($p in $procs) {
        $memMB = [math]::Round($p.WorkingSet / 1MB, 1)
        $msg += "$($p.Name): $memMB MB`n"
    }
    Show-Result "Top Processes" $msg
})

# Pending Reboot Button
$window.FindName("PendingRebootBtn").Add_Click({
    Animate-ProgressBar
    $pending = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -ErrorAction SilentlyContinue
    $msg = if ($pending) { "A reboot is pending." } else { "No pending reboot detected." }
    Show-Result "Reboot Status" $msg
})

# Firewall Status Button
$window.FindName("FirewallBtn").Add_Click({
    Animate-ProgressBar
    $msg = "=== FIREWALL STATUS ===`n"
    $fw = Get-NetFirewallProfile -Profile Domain,Public,Private
    foreach ($f in $fw) {
        $status = if ($f.Enabled) {"Enabled"} else {"Disabled"}
        $msg += "$($f.Name): $status`n"
    }
    Show-Result "Firewall Status" $msg
})

# Event Logs Button
$window.FindName("EventLogsBtn").Add_Click({
    Animate-ProgressBar
    $errors = Get-WinEvent -FilterHashtable @{LogName='System'; Level=2} -MaxEvents 5
    $msg = "=== RECENT SYSTEM ERRORS ===`n"
    foreach ($e in $errors) {
        $msg += "$($e.TimeCreated): $($e.Message)`n`n"
    }
    Show-Result "System Errors" $msg
})

# Battery Status
$window.FindName("BatteryBtn").Add_Click({
    Animate-ProgressBar
    $battery = Get-WmiObject -Class Win32_Battery
    $status = if ($battery.EstimatedChargeRemaining -eq $null) { "No battery" }
                 elseif ($battery.BatteryStatus -eq 2) { "Charging" }
                 else { "Discharging" }
    $msg = "=== BATTERY STATUS ===`n"
    $msg += "Status: $status`nCharge Remaining: $($battery.EstimatedChargeRemaining)%`n"
    Show-Result "Battery Status" $msg
})

# Malware Scan (Basic)
$window.FindName("MalwareScanBtn").Add_Click({
    Animate-ProgressBar
    $malwareProcesses = Get-Process | Where-Object { $_.Name -match "malware|trojan|virus" }
    $msg = "=== QUICK MALWARE SCAN ===`n"
    if ($malwareProcesses.Count -gt 0) {
        $msg += "Potential malware processes detected: `n"
        foreach ($proc in $malwareProcesses) {
            $msg += "$($proc.Name) (PID: $($proc.Id))`n"
        }
    } else {
        $msg += "No malware-related processes detected."
    }
    Show-Result "Malware Scan" $msg
})

# Disk Health (SMART)
$window.FindName("DiskHealthBtn").Add_Click({
    Animate-ProgressBar
    $disks = Get-WmiObject -Class Win32_DiskDrive
    $msg = "=== DISK HEALTH (SMART) ===`n"
    foreach ($disk in $disks) {
        $status = if ($disk.Status -eq "OK") { "Healthy" } else { "Failed" }
        $msg += "$($disk.DeviceID): $status`n"
    }
    Show-Result "Disk Health" $msg
})

# System Uptime
$window.FindName("UptimeBtn").Add_Click({
    Animate-ProgressBar
    $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $msg = "=== SYSTEM UPTIME ===`n"
    $msg += "System Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
    Show-Result "System Uptime" $msg
})

# Windows Defender Status
$window.FindName("DefenderBtn").Add_Click({
    Animate-ProgressBar
    $defenderStatus = Get-MpComputerStatus
    $msg = "=== WINDOWS DEFENDER STATUS ===`n"
    $msg += "Real-time protection: $($defenderStatus.RealTimeProtectionEnabled)`n"
    $msg += "Virus Signature Last Updated: $($defenderStatus.AntivirusSignatureLastUpdated)"
    Show-Result "Windows Defender" $msg
})

# System Temperature
$window.FindName("TempBtn").Add_Click({
    Animate-ProgressBar
    $msg = "=== SYSTEM TEMPERATURE ===`n"
    
    try {
        # First, check if the MSAcpi_ThermalZoneTemperature class exists using Get-CimInstance
        $cpuTemp = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        
        if ($cpuTemp) {
            # If the class is available, calculate the temperature (Kelvin to Celsius)
            $msg += "CPU Temperature: $([math]::Round(($cpuTemp.CurrentTemperature - 2732) / 10, 2)) °C"
        } else {
            # If the class isn't available, try using Get-WmiObject as a fallback
            $cpuTempFallback = Get-WmiObject -Namespace "root/wmi" -Class MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
            if ($cpuTempFallback) {
                $msg += "CPU Temperature: $([math]::Round(($cpuTempFallback.CurrentTemperature - 2732) / 10, 2)) °C"
            } else {
                $msg += "No temperature data available (Class not found)."
            }
        }
    } catch {
        # Catch any errors from both Get-CimInstance and Get-WmiObject
        $msg += "Error retrieving system temperature: $_"
    }

    Show-Result "System Temperature" $msg
})

# Show the Window
$window.ShowDialog()
