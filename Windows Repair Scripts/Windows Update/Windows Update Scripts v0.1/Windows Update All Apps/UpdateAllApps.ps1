<#
.SYNOPSIS
    Initiates software and driver upgrades through a WPF GUI with progress tracking.

.DESCRIPTION
    This PowerShell script provides a graphical user interface (GUI) for upgrading installed software and drivers on a system. Using the `winget` command-line tool, it upgrades all packages that have updates available. The script features a progress bar to visually indicate the status of the upgrade process, and a message box provides feedback to the user on the success or failure of the upgrade.

    The script checks for administrator rights and relaunches with elevated privileges if necessary. Upon initiating the upgrade process, the user is shown the upgrade progress, and a final message box is displayed when the upgrade is complete or if an error occurs.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Administrator rights for executing `winget upgrade --all` and upgrading software.
        - PowerShell 7+ or newer.
        - .NET Framework (for WPF and Windows Forms support).
        - `winget` must be installed and available in the system's PATH.

    This tool is useful for IT professionals, system administrators, or advanced users who need to update installed software and drivers quickly and efficiently.

    The script performs the following functions:
        - Displays a WPF window with a button to initiate the software and driver upgrades.
        - Uses the `winget` tool to silently upgrade all installed software and drivers.
        - Provides real-time feedback to the user via a progress bar and message boxes.
        - Handles errors during the upgrade process and notifies the user of any issues.
        
    This tool is designed for Windows 10/11 environments with administrator rights.
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

# Corrected XAML with escaped ampersands
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Software &amp; Driver Upgrade'
        ResizeMode='NoResize'
        WindowStartupLocation='CenterScreen'
        Background='#f4f4f4'
        FontFamily='Segoe UI'
        FontSize='12'
        SizeToContent='WidthAndHeight'>
    <StackPanel Margin='20' HorizontalAlignment='Center'>
        <TextBlock Text='Software &amp; Driver Upgrade' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='StartUpgradeButton' Content='Start Upgrade' Width='400' Height='20' Margin='0,0,0,20'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Value='0' Margin='0,0,0,10'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get UI elements
$StartUpgradeButton = $window.FindName("StartUpgradeButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Helper function to show message boxes
function Show-MessageBox {
    param (
        [string]$Message,
        [string]$Title = "Information",
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, $Icon)
}

# Helper function to update UI
function Update-UI {
    param (
        [string]$Message,
        [int]$PercentComplete = $null
    )
    if ($PercentComplete -ne $null) {
        $ProgressBar.Value = $PercentComplete
    }
    $StatusText.Text = $Message
    [System.Windows.Forms.Application]::DoEvents()
}

# Upgrade process function
function Start-Upgrade {
    Show-MessageBox -Message "Starting software and driver upgrades..." -Title "Upgrade Process"
    Update-UI "Starting upgrades...", 0

    for ($i = 0; $i -le 100; $i += 2) {
        if ($i -eq 100) {
            Show-MessageBox -Message "Running winget upgrade --all..." -Title "Upgrading Software"
            Update-UI "Running winget upgrade --all...", 100
        }
        else {
            Update-UI "Preparing upgrades... $i%", $i
        }
        Start-Sleep -Milliseconds 100
    }

    try {
        Update-UI "Upgrading software and drivers...", 0
        Show-MessageBox -Message "Upgrading software and drivers..." -Title "Upgrade in Progress"
        # Run winget upgrade silently
        winget upgrade --all --accept-source-agreements --accept-package-agreements | Out-Null
        Update-UI "Upgrade completed successfully.", 100
        Show-MessageBox -Message "Upgrade completed successfully." -Title "Upgrade Complete" -Icon Information
    }
    catch {
        Update-UI "An error occurred during upgrade.", 100
        Show-MessageBox -Message "An error occurred during upgrade.`n$_" -Title "Error" -Icon Error
    }
}

# Button click event
$StartUpgradeButton.Add_Click({
    # Disable button to prevent multiple clicks
    $StartUpgradeButton.IsEnabled = $false
    Start-Upgrade
    $StartUpgradeButton.IsEnabled = $true
})

# Show the window
$window.ShowDialog() | Out-Null
