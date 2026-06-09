<#
.SYNOPSIS
    Checks Windows OS version, build, install date, and shows the End-of-Life (EOL) status with a styled UI.

.DESCRIPTION
    This PowerShell script retrieves the current version, build, and installation date of the Windows OS from the system. It then compares the OS version with predefined EOL dates for various Windows 10 and Windows 11 builds. 

    The script uses a WPF-based graphical interface to display the results, showing the OS version, build, installation date, and the EOL status with a countdown of days remaining until the end of support. 

    The user interface is designed to be clean and user-friendly, featuring a progress bar and status text to guide the user through the scan process. It is intended for IT specialists, admins, and advanced users who need to check the EOL status of their Windows operating system.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2 and Windows 10 22H2

    Requirements :
        - Administrator privileges to access OS information.
        - PowerShell 7+ or newer.
        - .NET Framework (for WPF and Windows Forms support).

    Compatibility: Windows 10 (Build 19045) and above, including Windows 11 (Build 22621 and 25365).

    The script checks the OS version against a predefined list of EOL dates for several Windows 10 and Windows 11 versions:
        - Windows 10 22H2 (Build 19045) – EOL: 2025-10-14
        - Windows 11 22H2 (Build 22621) – EOL: 2027-10-14
        - Windows 11 24H2 (Build 25365) – EOL: 2029-10-08
        
    The tool informs the user whether their OS is approaching its end of life and provides recommendations for upgrading if necessary.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Updated XAML - matches "Outlook Cache Cleaner" UI
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Windows OS EOL Status Checker'
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
            <Setter Property='Height' Value='30'/>
            <Setter Property='Margin' Value='0,0,0,10'/>
        </Style>
    </Window.Resources>
    <StackPanel Margin='20' HorizontalAlignment='Center'>
        <TextBlock Text='Windows OS EOL Checker' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='CheckButton' Content='Check OS EOL Status'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Click "Check OS EOL Status" to begin.' FontSize='12' Foreground='black' Margin='0,0,0,10'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$checkButton = $window.FindName("CheckButton")
$progressBar = $window.FindName("ProgressBar")
$statusText  = $window.FindName("StatusText")

# Message box
function Show-MessageBox {
    param (
        [string]$Text,
        [string]$Title = "OS End-of-Life Status"
    )
    [System.Windows.Forms.MessageBox]::Show($Text, $Title, 'OK', 'Information') | Out-Null
}

# EOL check logic
function Check-OsEolStatus {
    try {
        $statusText.Text = "Retrieving OS information..."
        $progressBar.Value = 20
        [System.Windows.Forms.Application]::DoEvents()

        $os = Get-CimInstance Win32_OperatingSystem
        if (-not $os) {
            Show-MessageBox -Text "Unable to retrieve OS information." -Title "Error"
            $statusText.Text = "Failed to retrieve OS info."
            $progressBar.Value = 0
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
                $installDate = "Invalid date"
            }
        }

        $progressBar.Value = 60
        [System.Windows.Forms.Application]::DoEvents()

        # EOL versions
        $eolDates = @{
            "10.0.19045" = [datetime]"2025-10-14"  # Win10 22H2
            "10.0.22621" = [datetime]"2027-10-14"  # Win11 22H2
            "10.0.25365" = [datetime]"2029-10-08"  # Win11 24H2
        }

        $matchedEol = $eolDates.Keys | Where-Object { $osVersion.StartsWith($_) } | ForEach-Object { $eolDates[$_] }
        if (-not $matchedEol) { $matchedEol = [datetime]"2100-01-01" }

        $daysLeft = ($matchedEol - (Get-Date)).Days

        $report = @"
Operating System : $osName
Version          : $osVersion (Build $osBuild)
Installed On     : $installDate
End-of-Life Date : $matchedEol
Days Left        : $daysLeft

"@

        if ($daysLeft -lt 0) {
            $report += "Your OS is past its End of Life. Upgrade immediately."
        } elseif ($daysLeft -le 90) {
            $report += "Your OS support ends in less than 90 days. Consider upgrading soon."
        } else {
            $report += "Your OS is supported. No immediate action required."
        }

        $progressBar.Value = 100
        $statusText.Text = "Scan complete."
        Show-MessageBox -Text $report

    } catch {
        Show-MessageBox -Text "Unexpected error:`n$($_.Exception.Message)" -Title "Error"
        $statusText.Text = "Error during scan."
        $progressBar.Value = 0
    }
}

# Hook up event
$checkButton.Add_Click({
    $checkButton.IsEnabled = $false
    Check-OsEolStatus
    $checkButton.IsEnabled = $true
})

# Show window
$window.ShowDialog() | Out-Null
