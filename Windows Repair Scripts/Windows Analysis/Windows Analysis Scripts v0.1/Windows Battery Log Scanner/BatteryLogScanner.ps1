<#
.SYNOPSIS
    Scans battery health and recent CMOS/BIOS-related system events via WPF GUI.

.DESCRIPTION
    This PowerShell script provides a graphical user interface (GUI) that allows users to scan the health of the system's battery and review recent CMOS/BIOS-related events logged in the system event log. The script pulls detailed battery information, including charge status, estimated charge remaining, and chemistry. Additionally, it searches the system event log for relevant CMOS/BIOS or battery-related events. 

    The GUI provides a "Run Battery & BIOS Scan" button, and upon clicking, a progress bar updates as the scan runs. Once complete, the results are displayed in a Windows Forms message box. The tool is designed to work on portable devices with batteries, and it provides an informative battery health report.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Admin rights to access system event logs and battery reports.
        - .NET Framework (for WPF and WinForms)
        - PowerShell 7+ or newer

    The script is especially useful for IT professionals or advanced users who need to monitor battery health or troubleshoot BIOS/CMOS-related issues based on system logs.
    
    It performs the following functions:
        - Scans battery health and provides details such as charge status, chemistry, and the remaining charge.
        - Pulls recent CMOS, BIOS, or RTC-related events from the system event log.
        - Saves a detailed battery report as an HTML file for future reference.
        - Provides an easy-to-use WPF interface for scanning and displaying results.
        
    This tool is designed for Windows 11 systems with administrative rights.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define XAML layout (style matched)
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Battery &amp; BIOS Scanner'
        Height='460' Width='460'
        ResizeMode='NoResize'
        WindowStartupLocation='CenterScreen'
        Background='#f4f4f4'
        FontFamily='Segoe UI'
        FontSize='12'
        SizeToContent='WidthAndHeight'>
    <Window.Resources>
        <Style TargetType='Button'>
            <Setter Property='Background' Value='#f4f4f4'/>
            <Setter Property='Foreground' Value='Black'/>
            <Setter Property='BorderBrush' Value='#cccccc'/>
            <Setter Property='BorderThickness' Value='1'/>
            <Setter Property='FontWeight' Value='Bold'/>
            <Setter Property='Cursor' Value='Hand'/>
            <Setter Property='Width' Value='400'/>
            <Setter Property='Height' Value='20'/>
            <Setter Property='Margin' Value='0,0,0,10'/>
        </Style>
    </Window.Resources>
    <StackPanel Margin='20' HorizontalAlignment='Center'>
        <TextBlock Text='Battery &amp; CMOS/BIOS Scanner Tool' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='ScanButton' Content='Run Battery &amp; BIOS Scan'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Access UI elements
$ScanButton = $window.FindName("ScanButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText  = $window.FindName("StatusText")

# Show MessageBox without closing window
function Show-MessageBox {
    param (
        [string]$Text,
        [string]$Title = "Scan Results"
    )
    [System.Windows.Forms.MessageBox]::Show($Text, $Title, 'OK', 'Information') | Out-Null
}

# Battery info logic
function Get-BatteryHealth {
    $chassisType = (Get-CimInstance -Class Win32_SystemEnclosure).ChassisTypes
    $isPortable = $chassisType -contains 8 -or $chassisType -contains 9 -or $chassisType -contains 10 -or $chassisType -contains 14

    if ($isPortable) {
        $battery = Get-CimInstance -Class Win32_Battery
        if ($battery) {
            $batteryStatus = "Battery Detected:`n"
            $batteryStatus += "Charge Status: $($battery.BatteryStatus)`n"
            $batteryStatus += "Estimated Charge Remaining: $($battery.EstimatedChargeRemaining)%`n"
            $batteryStatus += "Chemistry: $($battery.Chemistry)`n"
            $reportPath = "$env:TEMP\battery-report.html"
            powercfg /batteryreport /output $reportPath | Out-Null
            $batteryStatus += "`nDetailed battery report saved to:`n$reportPath"
        } else {
            $batteryStatus = "Portable device detected, but no battery found."
        }
    } else {
        $batteryStatus = "Non-portable device detected. No battery expected."
    }

    return $batteryStatus
}

# BIOS-related logs
function Get-BIOSRelatedEvents {
    $events = Get-WinEvent -LogName System -MaxEvents 100 |
        Where-Object { $_.Message -match 'CMOS|BIOS|RTC|battery' }

    if ($events.Count -eq 0) {
        return "No CMOS/BIOS/Battery-related events found in the last 100 system events."
    }

    $eventSummary = "`nRecent CMOS/BIOS-related Events:`n"
    foreach ($event in $events) {
        $eventSummary += "- [$($event.TimeCreated)] $($event.Message.Substring(0, [Math]::Min(200, $event.Message.Length)))`n"
    }

    return $eventSummary
}

# Progress bar control
function Update-ProgressBar {
    param ([int]$value)
    $ProgressBar.Value = $value
}

# Click event handler
$ScanButton.Add_Click({
    $ScanButton.IsEnabled = $false
    Update-ProgressBar -value 10
    $StatusText.Text = "Scanning battery info..."

    $batteryInfo = Get-BatteryHealth
    Update-ProgressBar -value 50
    $StatusText.Text = "Scanning CMOS/BIOS logs..."

    $biosInfo = Get-BIOSRelatedEvents
    Update-ProgressBar -value 100
    $StatusText.Text = "Scan complete."

    Show-MessageBox -Text "$batteryInfo`n`n$biosInfo"

    $ProgressBar.Value = 0
    $StatusText.Text = "Ready."
    $ScanButton.IsEnabled = $true
})

# Show the GUI window
$null = $window.ShowDialog()
