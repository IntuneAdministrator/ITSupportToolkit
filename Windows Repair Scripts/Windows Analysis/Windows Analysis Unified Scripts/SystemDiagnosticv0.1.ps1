<#
.SYNOPSIS
    Performs a system diagnostic and health check with a WPF GUI.

.DESCRIPTION
    This script provides an interactive system diagnostic and health check tool using a WPF-based GUI. It includes tests for battery health, BIOS information, system info, BSOD events, OS end-of-life status, internet connectivity, and a general system health check (CPU, memory, disk, etc.). The script provides real-time feedback through a progress bar and displays results in message boxes. 

.NOTES
    Author       : Allester Padovani
    Date         : July 18, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Admin rights
        - Outlook installed
        - .NET Framework (for WPF and WinForms)
        - PowerShell 7+ or higher
    This script is suitable for IT specialists and general users who need a comprehensive overview of system health.

    Known Issues:
        - Requires elevated privileges (Admin rights).
        - Assumes a working internet connection for the "Internet Connectivity Test".

    Change History:
        - Version 1.0: Initial release.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load necessary assemblies
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing

# Define your XAML with escaped special characters (&amp;)
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="System Diagnostic &amp; Health Check Tool v0.1"
        Height="700" Width="460"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Background="#f4f4f4"
        FontFamily="Segoe UI"
        FontSize="12"
        SizeToContent="WidthAndHeight">
    <Window.Resources>
        <!-- Style for all buttons -->
        <Style TargetType="Button">
            <Setter Property="Background" Value="#f4f4f4"/>
            <Setter Property="Foreground" Value="Black"/>
            <Setter Property="BorderBrush" Value="#cccccc"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Width" Value="400"/>
            <Setter Property="Height" Value="20"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>
    </Window.Resources>
    <StackPanel Margin="20" HorizontalAlignment="Center">
        <TextBlock Text="System Diagnostic &amp; Health Check Tool v0.1" FontSize="16" FontWeight="Bold" Margin="0,0,0,20"
                   HorizontalAlignment="Center"/>
        <Button x:Name="BatteryButton" Content="Run Battery &amp; BIOS Scan"/>
        <Button x:Name="BSODButton" Content="Scan Last BSOD Event"/>
        <Button x:Name="BIOSInfoButton" Content="Show BIOS Information"/>
        <Button x:Name="SystemInfoButton" Content="Show System Info"/>
        <Button x:Name="EOLStatusButton" Content="Check OS EOL Status"/>
        <Button x:Name="InternetTestButton" Content="Internet Connectivity Test"/>
        <Button x:Name="ShowUptimeButton" Content="Show System Uptime"/>
        <Button x:Name="HealthCheckButton" Content="Start System Health Check"/>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="400" Minimum="0" Maximum="100" Margin="0,5,0,5" Value="0"/>
        <TextBlock x:Name="StatusText" Text="" FontSize="12" Foreground="black"/>
        <TextBlock Text=" Allester Padovani, Senior IT Specialist. All rights reserved." FontSize="12" FontStyle="Italic" Foreground="black" Margin="0,20,0,0" HorizontalAlignment="Center"/>
    </StackPanel>
</Window>
"@

# Load XAML into an XmlReader
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
# Load the window
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Retrieve controls
$BatteryButton      = $window.FindName("BatteryButton")
$BSODButton         = $window.FindName("BSODButton")
$BIOSInfoButton     = $window.FindName("BIOSInfoButton")
$SystemInfoButton   = $window.FindName("SystemInfoButton")
$EOLStatusButton    = $window.FindName("EOLStatusButton")
$InternetTestButton = $window.FindName("InternetTestButton")
$ShowUptimeButton   = $window.FindName("ShowUptimeButton")
$HealthCheckButton  = $window.FindName("HealthCheckButton")
$ProgressBar        = $window.FindName("ProgressBar")
$StatusText         = $window.FindName("StatusText")

# Log file path
$logFile = "C:\ProgramData\OzarkTechTeam\SystemHealth_log.txt"

# Helper functions
function Disable-Buttons {
    param([bool]$state)
    $BatteryButton.IsEnabled      = -not $state
    $BSODButton.IsEnabled         = -not $state
    $BIOSInfoButton.IsEnabled     = -not $state
    $SystemInfoButton.IsEnabled   = -not $state
    $EOLStatusButton.IsEnabled    = -not $state
    $InternetTestButton.IsEnabled = -not $state
    $ShowUptimeButton.IsEnabled   = -not $state
    $HealthCheckButton.IsEnabled  = -not $state
}

function Update-ProgressBar {
    param(
        [int]$Start = 0,
        [int]$End = 100,
        [string]$Message = ""
    )
    for ($i = $Start; $i -le $End; $i += 5) {
        $ProgressBar.Value = $i
        if ($Message) { $StatusText.Text = $Message }
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 80
    }
}

function Show-MessageBox {
    param (
        [string]$Text,
        [string]$Title = "System Diagnostic"
    )
    [System.Windows.Forms.MessageBox]::Show($Text, $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

# Battery and BIOS Scan functions
function Get-BatteryHealth {
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop
        if (-not $battery) {
            return "No battery detected on this system."
        } else {
            return "Battery is detected and operational."
        }
    }
    catch {
        return "Failed to retrieve battery info: $($_.Exception.Message)"
    }
}

function Get-BIOSRelatedEvents {
    try {
        $since = (Get-Date).AddDays(-7)
        $events = Get-WinEvent -FilterHashtable @{
            LogName='System'
            ID=12,13,14,15,16,17
            StartTime=$since
        } -ErrorAction Stop
        if ($events.Count -eq 0) {
            return "No recent BIOS/CMOS/RTC/Battery related events found in the last week."
        } else {
            return "Recent BIOS-related system events found."
        }
    }
    catch {
        return "Failed to retrieve BIOS related events: $($_.Exception.Message)"
    }
}

# BSOD scan
function Scan-BSODEvent {
    try {
        $events = Get-WinEvent -FilterHashtable @{LogName='System';ID=1001} -MaxEvents 5 -ErrorAction Stop | Where-Object {$_.Message -like "*BugCheckCode*"}
        if ($events.Count -eq 0) { return "No recent BSOD events found." }
        $report = "Recent BSOD Events:`n"
        foreach ($ev in $events) {
            $report += "Time: $($ev.TimeCreated)`n$($ev.Message)`n------------------------------------`n"
        }
        return $report
    }
    catch {
        return "Failed to retrieve BSOD events: $($_.Exception.Message)"
    }
}

# Show BIOS info
function Show-BIOSInfo {
    try {
        $bios = Get-CimInstance -ClassName Win32_BIOS
        $message = @"
BIOS Information:

Serial Number              : $($bios.SerialNumber)
Manufacturer               : $($bios.Manufacturer)
BIOS Version               : $($bios.SMBIOSBIOSVersion)
BIOS Release Date          : $($bios.ReleaseDate)
List Of Languages          : $($bios.ListOfLanguages -join ', ')
Primary BIOS               : $($bios.PrimaryBIOS)
SMBIOS Major Version       : $($bios.SMBIOSMajorVersion)
SMBIOS Minor Version       : $($bios.SMBIOSMinorVersion)
Software Element ID        : $($bios.SoftwareElementID)
Software Element State     : $($bios.SoftwareElementState)
Target Operating System    : $($bios.TargetOperatingSystem)
"@
        Show-MessageBox -Text $message -Title "Detailed BIOS Information"
    }
    catch {
        Show-MessageBox -Text "Failed to retrieve BIOS information.`n$($_.Exception.Message)" -Title "Error"
    }
}

# Show system info
function Show-SystemInfo {
    try {
        $info = Get-ComputerInfo | Select-Object `
            CsName, OsName, OsVersion, WindowsVersion, OsBuildNumber, OsArchitecture,
            CsManufacturer, CsModel, CsNumberOfLogicalProcessors, CsTotalPhysicalMemory,
            BiosManufacturer, BiosVersion

        $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Name).Trim()
        $mem = [math]::Round($info.CsTotalPhysicalMemory / 1GB, 2)

        $report = @"
System Information:

Computer Name     : $($info.CsName)
OS Name           : $($info.OsName)
OS Version        : $($info.OsVersion)
Windows Version   : $($info.WindowsVersion)
Build Number      : $($info.OsBuildNumber)
Architecture      : $($info.OsArchitecture)

Manufacturer      : $($info.CsManufacturer)
Model             : $($info.CsModel)
Processor         : $cpu
Logical Cores     : $($info.CsNumberOfLogicalProcessors)
Memory Installed  : $mem GB

BIOS Manufacturer : $($info.BiosManufacturer)
BIOS Version      : $($info.BiosVersion -join ", ")
"@
        Show-MessageBox -Text $report -Title "System Info"
    }
    catch {
        Show-MessageBox -Text "Error: $($_.Exception.Message)" -Title "Error"
    }
}

# Check OS EOL status
function Check-OsEolStatus {
    try {
        $StatusText.Text = "Retrieving OS information..."
        $ProgressBar.Value = 20
        [System.Windows.Forms.Application]::DoEvents()

        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        if (-not $os) {
            Show-MessageBox -Text "Failed to get OS information." -Title "Error"
            $StatusText.Text = "Failed to retrieve OS info."
            $ProgressBar.Value = 0
            return
        }

        $osName = $os.Caption
        $osVersion = $os.Version
        $osBuild = $os.BuildNumber
        $installDateRaw = $os.InstallDate

        if ([string]::IsNullOrEmpty($installDateRaw)) {
            $installDate = "Unknown"
        } else {
            try {
                $installDate = [Management.ManagementDateTimeConverter]::ToDateTime($installDateRaw)
            } catch {
                $installDate = "Invalid date format"
            }
        }

        $ProgressBar.Value = 60
        [System.Windows.Forms.Application]::DoEvents()

        # Example EOL dates for Windows versions
        $eolDates = @{
            "10.0.19045" = [datetime]"2025-10-14"  # Windows 10 22H2
            "10.0.22621" = [datetime]"2027-10-14"  # Windows 11 22H2
            "10.0.25365" = [datetime]"2029-10-08"  # Windows 11 24H2 (example)
        }

        $matchedEol = $null
        foreach ($key in $eolDates.Keys) {
            if ($osVersion.StartsWith($key)) {
                $matchedEol = $eolDates[$key]
                break
            }
        }
        if (-not $matchedEol) { $matchedEol = [datetime]"2100-01-01" }

        $daysLeft = ($matchedEol - (Get-Date)).Days

        $report = @"
Operating System: $osName
Version: $osVersion (Build $osBuild)
Installation Date: $installDate
Official End of Support Date: $matchedEol
Days Until End of Support: $daysLeft

"@

        if ($daysLeft -lt 0) {
            $report += "Your OS is past its End of Life date. Please upgrade immediately."
        } elseif ($daysLeft -le 90) {
            $report += "Your OS support will end soon. Consider upgrading within 3 months."
        } else {
            $report += "Your OS is supported. No immediate action needed."
        }

        $ProgressBar.Value = 100
        $StatusText.Text = "Check complete."
        Show-MessageBox -Text $report -Title "OS End-of-Life Scanner Results"
    }
    catch {
        Show-MessageBox -Text "An unexpected error occurred:`n$($_.Exception.Message)" -Title "Error"
        $StatusText.Text = "Error occurred."
        $ProgressBar.Value = 0
    }
}

# Internet connectivity test
function Run-InternetTest {
    try {
        $targetHost = "google.com"
        Disable-Buttons $true
        $StatusText.Text = "Initializing Internet test..."
        $ProgressBar.Value = 0
        [System.Windows.Forms.Application]::DoEvents()

        for ($i=0; $i -le 20; $i+=5) {
            $ProgressBar.Value = $i
            $StatusText.Text = "Initializing... $i%"
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }

        $StatusText.Text = "Pinging $targetHost..."
        $ProgressBar.Value = 30
        [System.Windows.Forms.Application]::DoEvents()

        $pings = Test-Connection -ComputerName $targetHost -Count 10 -ErrorAction Stop
        $ProgressBar.Value = 60
        $StatusText.Text = "Analyzing results..."
        [System.Windows.Forms.Application]::DoEvents()

        $grouped = $pings | Group-Object -Property Address
        $isSlow = $false
        $message = "Internet Connectivity Test Results:`n`n"

        foreach ($group in $grouped) {
            $ip = $group.Name
            $responses = $group.Group
            $sent = $responses.Count
            $received = ($responses | Where-Object { $_.StatusCode -eq 0 }).Count
            $lost = $sent - $received
            $lossPercent = [math]::Round(($lost / $sent) * 100, 2)
            $avgRTT = [math]::Round(($responses | Measure-Object -Property ResponseTime -Average).Average, 2)

            if ($avgRTT -gt 40) { $isSlow = $true }

            $message += @"
Target Host       : $targetHost
Resolved IP       : $ip
Packets Sent      : $sent
Packets Received  : $received
Packets Lost      : $lost
Packet Loss       : $lossPercent%
Average Latency   : $avgRTT ms
"@
            $message += "`n-------------------------------------------`n"
        }

        $ProgressBar.Value = 100
        $StatusText.Text = "Test complete."
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Seconds 1

        if ($isSlow) {
            [System.Windows.Forms.MessageBox]::Show(
                "Internet is super slow (latency > 40ms).`nPlease reach out to your provider as soon as possible.",
                "Performance Warning",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning)
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                $message,
                "Internet Connectivity Test",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Internet test failed.`n$($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        $StatusText.Text = "Internet test failed."
        $ProgressBar.Value = 0
    }
    finally {
        Disable-Buttons $false
    }
}

# Show system uptime (updated version based on event logs)
$ShowUptimeButton.Add_Click({
    try {
        # Animate progress bar from 0 to 100%
        for ($i = 0; $i -le 100; $i += 10) {
            $StatusText.Text = "Calculating uptime... $i%"
            $ProgressBar.Value = $i
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }

        # Retrieve the most recent Event ID 6005 ("Event Log service started")
        $bootEvent = Get-WinEvent -FilterHashtable @{ LogName='System'; Id=6005 } -MaxEvents 1
        if ($null -eq $bootEvent) {
            throw "Could not retrieve boot event from the System event log."
        }
        $bootTime = $bootEvent.TimeCreated
        $currentTime = Get-Date
        $uptime = $currentTime - $bootTime
        $uptimeFormatted = "{0} days, {1} hours, {2} minutes, {3} seconds" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds

        $message = @"
System Uptime Based on Event Logs:

Boot Time       : $bootTime
Current Time    : $currentTime
Uptime Duration : $uptimeFormatted
"@

        # Show message box with uptime info
        [System.Windows.Forms.MessageBox]::Show(
            $message,
            "Uptime Status",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        $StatusText.Text = "Uptime displayed successfully."
        $ProgressBar.Value = 100
    }
    catch {
        $StatusText.Text = "Error occurred: $_"
        $ProgressBar.Value = 0
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# Run-SystemHealthCheck function
function Run-SystemHealthCheck {
    try {
        $StatusText.Text = "Running system health check..."
        $ProgressBar.Value = 0
        [System.Windows.Forms.Application]::DoEvents()

        # Check CPU usage
        $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
        $cpuStatus = "CPU Usage: $([math]::Round($cpuUsage, 2))%"

        # Check memory usage
        $memInfo = Get-WmiObject Win32_OperatingSystem
        $memUsage = [math]::Round(($memInfo.TotalVisibleMemorySize - $memInfo.FreePhysicalMemory) / $memInfo.TotalVisibleMemorySize * 100, 2)
        $memoryStatus = "Memory Usage: $memUsage%"

        # Check disk space
        $disk = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"
        $diskStatus = ""
        foreach ($d in $disk) {
            $diskUsage = [math]::Round(($d.Size - $d.FreeSpace) / $d.Size * 100, 2)
            $diskStatus += "Drive $($d.DeviceID): $diskUsage% used`n"
        }

        # Check for system updates (example)
        $updates = Get-WmiObject -Class "Win32_QuickFixEngineering" | Where-Object { $_.Description -eq "Hotfix" }
        $updatesStatus = "Installed Updates: $($updates.Count)"

        # Compile report
        $report = @"
System Health Check Results:

$cpuStatus
$memoryStatus
$diskStatus
$updatesStatus
"@

        # Display results
        Show-MessageBox -Text $report -Title "System Health Check Results"

        # Update progress bar to 100%
        $ProgressBar.Value = 100
        $StatusText.Text = "Health check complete."
    }
    catch {
        $StatusText.Text = "Error during health check: $_"
        $ProgressBar.Value = 0
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

# Attach other event handlers
$BatteryButton.Add_Click({
    Disable-Buttons $true
    Update-ProgressBar -Start 0 -End 50 -Message "Running Battery & BIOS Scan..."
    $batteryReport = Get-BatteryHealth
    $biosEventsReport = Get-BIOSRelatedEvents
    Update-ProgressBar -Start 50 -End 100 -Message "Scan complete."
    Disable-Buttons $false
    Show-MessageBox -Text ($batteryReport + "`n`n" + $biosEventsReport) -Title "Battery & BIOS Scan Results"
})

$BSODButton.Add_Click({
    Disable-Buttons $true
    Update-ProgressBar -Start 0 -End 100 -Message "Scanning last BSOD events..."
    $bsodReport = Scan-BSODEvent
    Disable-Buttons $false
    Show-MessageBox -Text $bsodReport -Title "BSOD Event Scan Results"
})

$BIOSInfoButton.Add_Click({
    Disable-Buttons $true
    Update-ProgressBar -Start 0 -End 100 -Message "Retrieving BIOS information..."
    Show-BIOSInfo
    Disable-Buttons $false
    $ProgressBar.Value = 0
    $StatusText.Text = ""
})

$SystemInfoButton.Add_Click({
    Disable-Buttons $true
    Update-ProgressBar -Start 0 -End 100 -Message "Retrieving system information..."
    Show-SystemInfo
    Disable-Buttons $false
    $ProgressBar.Value = 0
    $StatusText.Text = ""
})

$EOLStatusButton.Add_Click({
    Disable-Buttons $true
    Update-ProgressBar -Start 0 -End 10 -Message "Checking OS EOL status..."
    Check-OsEolStatus
    Disable-Buttons $false
    $ProgressBar.Value = 0
})

$InternetTestButton.Add_Click({
    Run-InternetTest
})

$HealthCheckButton.Add_Click({
    Run-SystemHealthCheck
})

# Show the window
[void]$window.ShowDialog()
