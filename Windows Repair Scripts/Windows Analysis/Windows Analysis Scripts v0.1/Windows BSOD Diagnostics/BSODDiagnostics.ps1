<#
.SYNOPSIS
    Scans system event logs for the most recent Blue Screen (BSOD) error and displays the report.

.DESCRIPTION
    This PowerShell script scans the system event logs to find the most recent Blue Screen of Death (BSOD) event by checking for Event ID 1001 from the 'Microsoft-Windows-WER-SystemErrorReporting' provider. The script uses a WPF-based graphical interface to display the results. 

    When the user clicks the "Scan for Last BSOD Event" button, the script performs the scan, shows a progress bar, and then displays the details of the last BSOD event, including the time of occurrence and the associated error message. It also provides recommended actions for troubleshooting the issue, such as updating drivers, running memory diagnostics, and checking disk integrity.

    The user interface is designed for Windows 11 24H2 or higher, with a clean, minimalistic design following the author's UI guidelines.

.NOTES
    Author       : Allester Padovani
    Date         : July 16, 2025
    Version      : 1.1
    Tested On    : Windows 11 24H2
    Requirements :
        - Admin rights to access system event logs.
        - .NET Framework (for WPF and WinForms)
        - PowerShell 7+ or newer
        
    Compatibility: Windows 11 24H2 and above  
    The script retrieves the most recent BSOD event from the system logs and provides the user with an actionable report to resolve the issue.

    This tool is useful for IT specialists and advanced users who need quick access to Blue Screen events for troubleshooting.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load required assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# Define WPF UI with consistent design
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="BSOD Event Scanner"
        Height="460" Width="460"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Background="#f4f4f4"
        FontFamily="Segoe UI"
        FontSize="12"
        SizeToContent='WidthAndHeight'>
    <Window.Resources>
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
        <TextBlock Text="Blue Screen (BSOD) Scanner" FontSize="16" FontWeight="Bold" Margin="0,0,0,20" HorizontalAlignment="Center"/>
        <Button x:Name="ScanBSODButton" Content="Scan for Last BSOD Event"/>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="400" Minimum="0" Maximum="100" Margin="0,5,0,5" Value="0"/>
        <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="black"/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML into WPF window
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Access WPF controls
$ScanButton = $window.FindName("ScanBSODButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Show message box without closing main window
function Show-MessageBox {
    param (
        [string]$Text,
        [string]$Title = "BSOD Event Report"
    )
    [System.Windows.Forms.MessageBox]::Show($Text, $Title, 'OK', 'Information') | Out-Null
}

# Update progress bar with animation
function Show-Progress {
    param (
        [int]$DurationSeconds = 4
    )
    $StatusText.Text = "Scanning for BSOD events..."
    $ProgressBar.Value = 0

    $steps = 100
    $delay = ($DurationSeconds * 1000) / $steps
    for ($i = 0; $i -le $steps; $i++) {
        $ProgressBar.Value = $i
        Start-Sleep -Milliseconds $delay
        [System.Windows.Forms.Application]::DoEvents()
    }

    $StatusText.Text = "Scan complete."
}

# Scan for BSOD Event
function Scan-BSOD {
    try {
        $bsodEvent = Get-WinEvent -FilterHashtable @{
            LogName      = 'System'
            ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'
            Id           = 1001
        } -MaxEvents 1 -ErrorAction SilentlyContinue

        if ($bsodEvent) {
            $time = $bsodEvent.TimeCreated.ToLocalTime()
            $msg  = $bsodEvent.Message.Trim()

            $report = @"
Last Blue Screen (BSOD) Detected:

Time: $time

Details:
$msg

Recommended Actions:
- Review the STOP code shown above
- Update device drivers and Windows patches
- Run memory diagnostics (Windows Memory Diagnostic)
- Check disk integrity (chkdsk)
- Review recent Windows Updates
"@

            Show-MessageBox -Text $report
        } else {
            Show-MessageBox -Text "No BSOD (Event ID 1001) was found in the recent system logs." -Title "BSOD Status"
        }
    }
    catch {
        Show-MessageBox -Text "An error occurred while scanning for BSOD events:`n$($_.Exception.Message)" -Title "Error"
    }
}

# Wire up button click
$ScanButton.Add_Click({
    $ScanButton.IsEnabled = $false
    Show-Progress -DurationSeconds 4
    Scan-BSOD
    $ProgressBar.Value = 0
    $StatusText.Text = "Ready."
    $ScanButton.IsEnabled = $true
})

# Show window
$window.ShowDialog() | Out-Null
