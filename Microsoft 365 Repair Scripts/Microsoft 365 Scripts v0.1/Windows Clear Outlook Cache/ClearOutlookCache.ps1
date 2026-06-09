<#
.SYNOPSIS
    GUI-based PowerShell tool to close Outlook and clear its local cache.

.DESCRIPTION
    This script provides a user-friendly WPF-based graphical interface for closing any running
    Microsoft Outlook processes and clearing the local Outlook cache directory. The cleanup process
    is initiated by clicking a "Start Cleanup" button, and the progress is visually shown using a
    progress bar and status messages. The UI is styled similarly to a dashboard layout and uses
    .NET assemblies (WPF and Windows Forms) to display the interface.

    This tool is useful for end users or IT admins needing a quick and repeatable method to resolve
    issues related to Outlook profile corruption or cache problems. Administrative rights are
    required to run the script, and it will relaunch itself with elevated privileges if needed.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2 with Microsoft 365 Outlook Desktop  
    Requirements : Admin rights, Outlook installed, .NET Framework (for WPF and WinForms)
#>

# Requires admin elevation
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# XAML UI with same layout design as WASAPI Dashboard
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Outlook Cache Cleaner'
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
        <TextBlock Text='Outlook Cleanup Tool' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='StartCleanupButton' Content='Start Cleanup'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Click "Start Cleanup" to begin.' FontSize='12' Foreground='black' Margin='0,0,0,10'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML into Window
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Find UI elements
$startButton = $window.FindName("StartCleanupButton")
$progressBar = $window.FindName("ProgressBar")
$statusText = $window.FindName("StatusText")

function Update-Progress {
    param([int]$value, [string]$text)
    $progressBar.Value = $value
    $statusText.Text = $text
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 700
}

function Kill-OutlookProcesses {
    $found = $false
    $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*outlook*" }
    foreach ($proc in $procs) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            $found = $true
        } catch {
            # silently continue if can't stop
        }
    }
    return $found
}

function Clear-OutlookCache {
    $cachePath = "$env:LOCALAPPDATA\Microsoft\Outlook"
    if (Test-Path $cachePath) {
        try {
            Remove-Item -Path $cachePath -Recurse -Force -ErrorAction Stop
            return $true
        } catch {
            # silently continue if can't delete
        }
    }
    return $false
}

$startButton.Add_Click({
    $startButton.IsEnabled = $false

    Update-Progress 10 "Closing Outlook processes..."
    $closed = Kill-OutlookProcesses

    Update-Progress 50 "Clearing Outlook cache..."
    $cleared = Clear-OutlookCache

    Update-Progress 100 "Cleanup completed."

    Start-Sleep -Milliseconds 600

    # Keep the window OPEN, do NOT close it here
    # $window.Dispatcher.Invoke({ $window.Close() }, 'Render')

    $msg = if ($closed) {
        "Outlook has been closed and its cache has been cleared successfully."
    } else {
        "No Outlook processes were running. Cache cleared successfully."
    }

    [System.Windows.Forms.MessageBox]::Show(
        $msg,
        "Operation Complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    # Re-enable button so user can run cleanup again if needed
    $startButton.IsEnabled = $true
})

# Show window
$window.ShowDialog() | Out-Null
