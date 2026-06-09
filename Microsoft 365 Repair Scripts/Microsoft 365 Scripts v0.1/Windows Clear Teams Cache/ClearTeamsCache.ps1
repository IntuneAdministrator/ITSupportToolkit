<#
.SYNOPSIS
    WPF GUI to terminate Microsoft Teams and clean its cache folders.

.DESCRIPTION
    Provides a WPF-based GUI interface that terminates all Microsoft Teams processes and deletes both local and roaming cache folders.
    Displays real-time progress via a WPF progress bar and confirms completion using a Windows Forms message box.

.AUTHOR
    Name        : Allester Padovani
    Title       : Senior IT Specialist
    Script Ver. : 1.0
    Date        : 2025-07-19

.NOTES
    Technologies:
        - WPF (inline XAML)
        - System.Windows.Forms for DoEvents and MessageBox
        - PresentationFramework.dll for WPF rendering
        - Compatible with Windows 11 24H2 and later
#>

# Ensure the script runs as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    $psi.WindowStyle = "Hidden"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}

# Load required assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# Define inline XAML with WASAPI Audio Dashboard styling/layout
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Teams Cache Cleaner'
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
        <TextBlock Text='Microsoft Teams Cache Cleaner' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='btnClean' Content='Start Cleanup'/>
        <ProgressBar x:Name='progressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='txtStatus' Text='Ready' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Parse and load XAML
[xml]$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDoc.LoadXml($xaml)
$reader = New-Object System.Xml.XmlNodeReader $xmlDoc
$window = [Windows.Markup.XamlReader]::Load($reader)

# Find controls
$btnClean = $window.FindName("btnClean")
$progressBar = $window.FindName("progressBar")
$txtStatus = $window.FindName("txtStatus")

# Helper to keep UI responsive
function Do-Events { [System.Windows.Forms.Application]::DoEvents() }

# Button click event handler
$btnClean.Add_Click({

    $btnClean.IsEnabled = $false
    $txtStatus.Text = "Terminating Teams processes..."
    Do-Events

    # Get all Teams processes
    $teamsProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*teams*" }
    $count = $teamsProcesses.Count
    $index = 0

    # Kill Teams processes with progress update
    foreach ($proc in $teamsProcesses) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        } catch {}
        $index++
        $progressBar.Value = [math]::Round(($index / ($count + 3)) * 100)
        $txtStatus.Text = "Killing: $($proc.ProcessName)"
        Do-Events
    }

    # Remove cache folders
    $txtStatus.Text = "Removing cache folders..."
    Do-Events
    Start-Sleep -Milliseconds 500

    $paths = @(
        "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe",
        "$env:APPDATA\Microsoft\Teams"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            } catch {}
        }
        $index++
        $progressBar.Value = [math]::Round(($index / ($count + 3)) * 100)
        Do-Events
    }

    # Final update
    $progressBar.Value = 100
    $txtStatus.Text = "Cleanup completed."
    Do-Events

    Start-Sleep -Milliseconds 800

    [System.Windows.Forms.MessageBox]::Show(
        "Microsoft Teams cache and temporary files have been removed.",
        "Cleanup Complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    $btnClean.IsEnabled = $true
    $txtStatus.Text = "Ready"
    $progressBar.Value = 0
})

# Show window (blocking)
$window.ShowDialog() | Out-Null
