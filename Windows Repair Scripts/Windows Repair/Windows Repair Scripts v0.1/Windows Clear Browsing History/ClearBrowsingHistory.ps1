<#
.SYNOPSIS
    GUI tool to clean Microsoft Edge and Internet Explorer browsing data with progress feedback.

.DESCRIPTION
    Provides a WPF window with a button to start cleaning browser data.
    Shows a progress bar that updates during cleanup.
    Displays a message box on completion or error.

    The script cleans browsing data for Microsoft Edge and Internet Explorer by deleting the following:
    - Microsoft Edge: History, Cookies, Downloads, Media History, Visited Links, Top Sites, Preferences, Sessions, etc.
    - Internet Explorer: History, Cookies, Cache, and other tracking data using system commands.

    This script utilizes the `ClearMyTracksByProcess` method for Internet Explorer and manually deletes relevant files for Microsoft Edge.

.AUTHOR
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2

.NOTES
    Requires: Windows 11 24H2+, .NET Framework, and permissions to delete browser files.
    Tested on: Windows 11 24H2.
    Known Issues:
        - Files that are currently in use or locked by the browser may not be deleted.
        - Might not work on older versions of Edge or Internet Explorer.
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

# Define XAML layout (updated for browser cleaning)
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Browser Data Cleaner'
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
        <TextBlock Text='Microsoft Edge &amp; Internet Explorer Cleaner Tool' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='CleanButton' Content='Clean Browsing Data'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

$StatusLabel = $window.FindName("StatusText")
$ProgressBar = $window.FindName("ProgressBar")
$CleanButton = $window.FindName("CleanButton")

# UI update helper
function Update-UI {
    param([string]$Message, [int]$Percent = $null)
    $window.Dispatcher.Invoke([action] {
        $StatusLabel.Text = $Message
        if ($Percent -ne $null) {
            $ProgressBar.Value = [math]::Min([math]::Max($Percent, 0), 100)
        }
        [System.Windows.Forms.Application]::DoEvents()
    })
}

# Cleanup functions
function Clear-EdgeData {
    Update-UI "Cleaning Microsoft Edge data..." 30
    $EdgeDataPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
    if (Test-Path $EdgeDataPath) {
        $itemsToDelete = @(
            "$EdgeDataPath\History",
            "$EdgeDataPath\Cookies",
            "$EdgeDataPath\Downloads",
            "$EdgeDataPath\Media History",
            "$EdgeDataPath\Visited Links",
            "$EdgeDataPath\Top Sites",
            "$EdgeDataPath\Network Action Predictor",
            "$EdgeDataPath\Preferences",
            "$EdgeDataPath\Sessions",
            "$EdgeDataPath\QuotaManager",
            "$EdgeDataPath\Service Worker"
        )
        foreach ($item in $itemsToDelete) {
            if (Test-Path $item) {
                try {
                    Remove-Item $item -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    # Ignore errors if files are locked or in use
                }
            }
        }
    }
    # Clear Media Foundation data
    try {
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Media Player\*.*" -Recurse -Force -ErrorAction SilentlyContinue
    } catch {}
    Update-UI "Microsoft Edge data cleaned." 50
}

function Clear-InternetExplorerData {
    Update-UI "Cleaning Internet Explorer data..." 70
    $flags = 1 + 2 + 8 + 16 + 32 + 16384
    Start-Process -FilePath "RunDll32.exe" -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess $flags" -Wait -NoNewWindow

    $regPath = "HKCU:\Software\Microsoft\Internet Explorer\Privacy"
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "ClearBrowsingHistoryOnExit" -Value 1

    Update-UI "Internet Explorer data cleaned." 90
}

# Button click handler
$CleanButton.Add_Click({
    try {
        $CleanButton.IsEnabled = $false
        Update-UI "Starting browser data cleanup..." 10

        Clear-EdgeData
        Start-Sleep -Seconds 1
        Clear-InternetExplorerData

        Update-UI "Cleanup complete." 100
        [System.Windows.Forms.MessageBox]::Show(
            "Microsoft Edge and Internet Explorer browsing data were successfully cleaned.",
            "Cleanup Complete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred: $_",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        Update-UI "Error during cleanup." 0
    }
    finally {
        $CleanButton.IsEnabled = $true
    }
})

# Show the WPF window
[void]$window.ShowDialog()
