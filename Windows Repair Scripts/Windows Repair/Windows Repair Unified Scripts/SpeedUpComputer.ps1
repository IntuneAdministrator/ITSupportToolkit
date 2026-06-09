<#
.SYNOPSIS
    Windows Performance Tweaks GUI - Modern UI

.DESCRIPTION
    Provides a GUI with performance-enhancing tasks like uninstalling antivirus,
    disabling startup apps, disk defragmentation, visual tweaks, etc.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Admin rights to access system event logs and battery reports.
        - .NET Framework (for WPF and WinForms)
        - PowerShell 7+ or newer
#>

# Ensure script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# WPF XAML - Modern Layout
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Speed Up Windows Computer Performance Tweaks"
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
            <Setter Property="Width" Value="400"/>
            <Setter Property="Height" Value="20"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>
    </Window.Resources>
    <StackPanel Margin="20" HorizontalAlignment="Center">
        <TextBlock Text="Speed Up Windows Computer Performance Tweaks" FontSize="16" FontWeight="Bold" Margin="0,0,0,20"
                   HorizontalAlignment="Center"/>
        <Button x:Name="BtnUninstallExtraAV" Content="Uninstall Extra Antivirus Programs"/>
        <Button x:Name="BtnDisableStartupApps" Content="Disable Startup Programs"/>
        <Button x:Name="BtnRunCheckDisk" Content="Run Check Disk for Errors"/>
        <Button x:Name="BtnDefragDisk" Content="Defragment Hard Disk"/>
        <Button x:Name="BtnTurnOffVisualEffects" Content="Turn Off Visual Effects"/>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="400" Minimum="0" Maximum="100" Margin="0,5,0,5" Value="0"/>
        <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="black"/>
        <TextBlock Text=" Allester Padovani, Senior IT Specialist. All rights reserved." FontSize="12" FontStyle="Italic" Foreground="black" Margin="0,20,0,0" HorizontalAlignment="Center"/>
    </StackPanel>
</Window>
"@

# Load UI
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$statusText = $window.FindName("StatusText")
$progressBar = $window.FindName("ProgressBar")

$btnUninstallExtraAV     = $window.FindName("BtnUninstallExtraAV")
$btnDisableStartupApps   = $window.FindName("BtnDisableStartupApps")
$btnRunCheckDisk         = $window.FindName("BtnRunCheckDisk")
$btnDefragDisk           = $window.FindName("BtnDefragDisk")
$btnTurnOffVisualEffects = $window.FindName("BtnTurnOffVisualEffects")

function Update-Status {
    param([string]$msg, [int]$progress = -1)
    $statusText.Text = $msg
    if ($progress -ge 0) { $progressBar.Value = $progress }
    [System.Windows.Forms.Application]::DoEvents()
}

function Run-Action {
    param (
        [ScriptBlock]$Action,
        [string]$StartMessage,
        [string]$SuccessMessage,
        [System.Windows.Controls.Button]$Button
    )

    $Button.IsEnabled = $false
    Update-Status -msg $StartMessage -progress 0
    $progressBar.Visibility = "Visible"

    try {
        & $Action
        Update-Status -msg $SuccessMessage -progress 100
    } catch {
        Update-Status -msg "Error: $_"
    } finally {
        $Button.IsEnabled = $true
        $progressBar.Visibility = "Collapsed"
    }
}

function Simulated-Progress {
    param (
        [System.Diagnostics.Process]$proc,
        [string]$StartMessage
    )
    $progress = 0
    while (-not $proc.HasExited) {
        if ($progress -lt 95) { $progress += 1 }
        Update-Status "$StartMessage - $progress%" $progress
        Start-Sleep -Milliseconds 300
    }
    Update-Status "$StartMessage - 100%" 100
}

# === Button Actions ===

$btnUninstallExtraAV.Add_Click({
    Run-Action -StartMessage "Opening Programs & Features..." -SuccessMessage "Control Panel opened." -Button $btnUninstallExtraAV -Action {
        Start-Process "appwiz.cpl"
    }
})

$btnDisableStartupApps.Add_Click({
    Run-Action -StartMessage "Opening Task Manager Startup tab..." -SuccessMessage "Task Manager opened." -Button $btnDisableStartupApps -Action {
        Start-Process "taskmgr.exe" -ArgumentList "/startup"
    }
})

$btnRunCheckDisk.Add_Click({
    $btnRunCheckDisk.IsEnabled = $false
    $progressBar.Visibility = "Visible"
    $progressBar.Value = 0
    Update-Status "Running CHKDSK on C:..."

    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "chkdsk C:" -NoNewWindow -PassThru
    Simulated-Progress -proc $proc -StartMessage "Running CHKDSK on C:"
    
    $progressBar.Visibility = "Collapsed"
    Update-Status "Check Disk completed."
    $btnRunCheckDisk.IsEnabled = $true
})

$btnDefragDisk.Add_Click({
    $btnDefragDisk.IsEnabled = $false
    $progressBar.Visibility = "Visible"
    $progressBar.Value = 0
    Update-Status "Defragmenting C:..."

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "defrag.exe"
    $psi.Arguments = "C: -w"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $proc = [System.Diagnostics.Process]::Start($psi)

    while (-not $proc.HasExited) {
        while (!$proc.StandardOutput.EndOfStream) {
            $line = $proc.StandardOutput.ReadLine()
            if ($line -match "(\d+)%") {
                $percent = [int]$matches[1]
                Update-Status "Defragmenting C: - $percent%" $percent
            }
        }
        Start-Sleep -Milliseconds 200
    }

    $progressBar.Value = 100
    Update-Status "Defragmentation completed."
    $progressBar.Visibility = "Collapsed"
    $btnDefragDisk.IsEnabled = $true
})

$btnTurnOffVisualEffects.Add_Click({
    Run-Action -StartMessage "Opening Performance Options..." -SuccessMessage "Performance options opened." -Button $btnTurnOffVisualEffects -Action {
        Start-Process "SystemPropertiesPerformance.exe"
    }
})

# Show UI
$window.ShowDialog() | Out-Null
