<#
.TITLE
    Outlook & Office Repair Tool + Teams Cache Cleaner - WPF GUI

.SYNOPSIS
    GUI tool to reset Outlook views, reset Outlook rules, run Office Quick or Full repair,
    clean Microsoft Teams cache, and clean Outlook cache.

.DESCRIPTION
    This script presents six buttons:
    - Reset Outlook Views (/cleanviews)
    - Reset Outlook Rules (/cleanrules)
    - Run Office Quick Repair (silent)
    - Run Office Full Repair (silent)
    - Clean Microsoft Teams cache
    - Clean Outlook Cache (close Outlook and delete cache folder)
    Each operation runs independently, provides a progress bar, and uses WinForms message boxes.

.NOTES
    Author       : Allester Padovani
    Title        : Senior IT Specialist
    Version      : 1.5
    Date         : 2025-07-19
    Compatibility: Windows 10/11, Outlook 2013+, OfficeClickToRun, Teams (UWP/Desktop)
    Requirements : Admin rights, .NET Framework
#>

# Elevate if not admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    try {
        Start-Process powershell -Verb RunAs -ArgumentList $arguments
    } catch {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("Administrator privileges are required to run this script.", "Permission Denied", "OK", "Error")
    }
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Correctly escaped XAML with 6 buttons, no fixed Height/Width
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Microsoft 365 &amp; Teams Repair"
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
        <TextBlock Text="Microsoft 365 &amp; Teams Repair" FontWeight="Bold" FontSize="16" Margin="0,0,0,20" TextAlignment="Center"/>
        <Button x:Name="ResetViewsButton" Content="Reset Outlook Views (/cleanviews)"/>
        <Button x:Name="ResetRulesButton" Content="Reset Outlook Rules (/cleanrules)"/>
        <Button x:Name="QuickRepairButton" Content="Run Office Quick Repair"/>
        <Button x:Name="FullRepairButton" Content="Run Office Full Repair"/>
        <Button x:Name="TeamsCleanButton" Content="Clean Microsoft Teams Cache"/>
        <Button x:Name="OutlookCacheCleanButton" Content="Clean Outlook Cache"/>
        <ProgressBar Name="ProgressBar" Height="20" Minimum="0" Maximum="100" Value="0" Margin="0,15,0,0"/>
        <TextBlock Name="StatusText" Text="" Margin="0,10,0,10" TextAlignment="Center"/>
        <TextBlock Text=" Allester Padovani, Senior IT Specialist. All rights reserved." FontSize="12" FontStyle="Italic" Foreground="black" Margin="0,20,0,0" HorizontalAlignment="Center"/>
    </StackPanel>
</Window>
"@

# Load XAML into the Window object
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$Window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get controls
$ResetViewsButton = $Window.FindName("ResetViewsButton")
$ResetRulesButton = $Window.FindName("ResetRulesButton")
$QuickRepairButton = $Window.FindName("QuickRepairButton")
$FullRepairButton = $Window.FindName("FullRepairButton")
$TeamsCleanButton = $Window.FindName("TeamsCleanButton")
$OutlookCacheCleanButton = $Window.FindName("OutlookCacheCleanButton")
$ProgressBar = $Window.FindName("ProgressBar")
$StatusText = $Window.FindName("StatusText")

function Do-Events { [System.Windows.Forms.Application]::DoEvents() }

function Update-Progress {
    param (
        [string]$Message,
        [int]$TargetValue
    )
    $StatusText.Text = $Message
    for ($i = $ProgressBar.Value; $i -lt $TargetValue; $i++) {
        $ProgressBar.Value = $i
        Do-Events
        Start-Sleep -Milliseconds 25
    }
}

function Disable-AllButtons {
    $ResetViewsButton.IsEnabled = $false
    $ResetRulesButton.IsEnabled = $false
    $QuickRepairButton.IsEnabled = $false
    $FullRepairButton.IsEnabled = $false
    $TeamsCleanButton.IsEnabled = $false
    $OutlookCacheCleanButton.IsEnabled = $false
}

function Enable-AllButtons {
    $ResetViewsButton.IsEnabled = $true
    $ResetRulesButton.IsEnabled = $true
    $QuickRepairButton.IsEnabled = $true
    $FullRepairButton.IsEnabled = $true
    $TeamsCleanButton.IsEnabled = $true
    $OutlookCacheCleanButton.IsEnabled = $true
}

function Get-OutlookPath {
    $paths = @(
        "$env:ProgramFiles\Microsoft Office\root\Office16\OUTLOOK.EXE",
        "$env:ProgramFiles(x86)\Microsoft Office\root\Office16\OUTLOOK.EXE",
        "$env:ProgramFiles\Microsoft Office\Office16\OUTLOOK.EXE",
        "$env:ProgramFiles(x86)\Microsoft Office\Office16\OUTLOOK.EXE"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) { return $path }
    }
    $cmd = Get-Command outlook.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Reset-Outlook {
    param (
        [string]$Argument,
        [string]$OperationName
    )
    Disable-AllButtons
    $ProgressBar.Value = 0

    $outlookPath = Get-OutlookPath
    if (-not $outlookPath) {
        [System.Windows.MessageBox]::Show("Outlook.exe not found. Please ensure Outlook is installed.", "Outlook Not Found", "OK", "Error")
        Enable-AllButtons
        return
    }

    Update-Progress -Message "Checking for running Outlook process..." -TargetValue 20
    Get-Process outlook -ErrorAction SilentlyContinue | ForEach-Object {
        $StatusText.Text = "Terminating Outlook (PID: $($_.Id))..."
        $_.Kill()
        Do-Events
    }

    Update-Progress -Message "Waiting for Outlook to close..." -TargetValue 40
    Start-Sleep -Seconds 2

    Update-Progress -Message "Launching Outlook with $Argument..." -TargetValue 70
    Start-Process -FilePath $outlookPath -ArgumentList $Argument
    Start-Sleep -Seconds 2

    Update-Progress -Message "$OperationName complete." -TargetValue 100
    $StatusText.Text = "Done. You may close this window."

    [System.Windows.MessageBox]::Show("Outlook $OperationName has been completed successfully.", "Success", "OK", "Information")
    Enable-AllButtons
}

function Run-OfficeQuickRepair {
    Disable-AllButtons
    $ProgressBar.Value = 0
    Update-Progress -Message "Preparing to start Quick Repair..." -TargetValue 25

    $clickToRunPath = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    if (-not (Test-Path $clickToRunPath)) {
        [System.Windows.MessageBox]::Show("OfficeClickToRun.exe not found. Please verify Microsoft Office is installed.", "Error", "OK", "Error")
        Enable-AllButtons
        return
    }

    Update-Progress -Message "Launching Office Quick Repair..." -TargetValue 60

    Start-Process -FilePath $clickToRunPath `
        -ArgumentList "scenario=Repair platform=x64 culture=en-us forceappshutdown=True RepairType=QuickRepair DisplayLevel=True" `
        -WindowStyle Hidden

    Start-Sleep -Seconds 5
    Update-Progress -Message "Repair process started." -TargetValue 100
    $StatusText.Text = "Office Quick Repair launched successfully."

    [System.Windows.MessageBox]::Show("Microsoft Office Quick Repair has been initiated.", "Repair Started", "OK", "Information")
    Enable-AllButtons
}

function Run-OfficeFullRepair {
    Disable-AllButtons
    $ProgressBar.Value = 0
    Update-Progress -Message "Preparing to start Full Repair..." -TargetValue 25

    $clickToRunPath = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    if (-not (Test-Path $clickToRunPath)) {
        [System.Windows.MessageBox]::Show("OfficeClickToRun.exe not found. Please verify Microsoft Office is installed.", "Error", "OK", "Error")
        Enable-AllButtons
        return
    }

    Update-Progress -Message "Launching Office Full Repair..." -TargetValue 60

    Start-Process -FilePath $clickToRunPath `
        -ArgumentList "scenario=Repair platform=x64 culture=en-us forceappshutdown=True RepairType=FullRepair DisplayLevel=True" `
        -WindowStyle Hidden

    Start-Sleep -Seconds 5
    Update-Progress -Message "Repair process started." -TargetValue 100
    $StatusText.Text = "Office Full Repair launched successfully."

    [System.Windows.MessageBox]::Show("Microsoft Office Full Repair has been initiated.", "Repair Started", "OK", "Information")
    Enable-AllButtons
}

function Clean-TeamsCache {
    Disable-AllButtons
    $ProgressBar.Value = 0
    $StatusText.Text = "Terminating Teams processes..."
    Do-Events

    $teamsProcesses = Get-Process | Where-Object { $_.ProcessName -like "*teams*" }
    $count = $teamsProcesses.Count
    $index = 0

    foreach ($proc in $teamsProcesses) {
        try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch {}
        $index++
        $ProgressBar.Value = [math]::Round(($index / ($count + 3)) * 100)
        $StatusText.Text = "Killing: $($proc.ProcessName)"
        Do-Events
    }

    $StatusText.Text = "Removing cache folders..."
    Do-Events
    Start-Sleep -Milliseconds 500

    $paths = @(
        "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe",
        "$env:APPDATA\Microsoft\Teams"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) {
            try { Remove-Item -Path $path -Recurse -Force -ErrorAction Stop } catch {}
        }
        $index++
        $ProgressBar.Value = [math]::Round(($index / ($count + 3)) * 100)
        Do-Events
    }

    $ProgressBar.Value = 100
    $StatusText.Text = "Teams cleanup completed."
    Do-Events
    Start-Sleep -Milliseconds 800

    [System.Windows.Forms.MessageBox]::Show(
        "Microsoft Teams cache and temporary files have been removed.",
        "Cleanup Complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    Enable-AllButtons
    $StatusText.Text = "Ready"
    $ProgressBar.Value = 0
}

function Clean-OutlookCache {
    Disable-AllButtons
    $ProgressBar.Value = 0

    Update-Progress -Message "Closing Outlook processes..." -TargetValue 20

    $closed = $false
    $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*outlook*" }
    foreach ($proc in $procs) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            $closed = $true
        } catch {}
    }

    Update-Progress -Message "Clearing Outlook cache folder..." -TargetValue 60

    $cachePath = "$env:LOCALAPPDATA\Microsoft\Outlook"
    if (Test-Path $cachePath) {
        try {
            Remove-Item -Path $cachePath -Recurse -Force -ErrorAction Stop
        } catch {
            [System.Windows.MessageBox]::Show("Failed to remove Outlook cache folder: $_", "Error", "OK", "Error")
            Enable-AllButtons
            return
        }
    }

    Update-Progress -Message "Operation completed." -TargetValue 100
    $StatusText.Text = "Outlook cache cleaned."

    Start-Sleep -Milliseconds 600

    $msg = if ($closed) {
        "Outlook processes were closed and cache cleared successfully."
    } else {
        "No Outlook processes were running. Cache cleared successfully."
    }

    [System.Windows.Forms.MessageBox]::Show(
        $msg,
        "Outlook Cache Cleanup",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    Enable-AllButtons
    $StatusText.Text = "Ready"
    $ProgressBar.Value = 0
}

# Hook button events
$ResetViewsButton.Add_Click({ Reset-Outlook -Argument "/cleanviews" -OperationName "views reset" })
$ResetRulesButton.Add_Click({ Reset-Outlook -Argument "/cleanrules" -OperationName "rules reset" })
$QuickRepairButton.Add_Click({ Run-OfficeQuickRepair })
$FullRepairButton.Add_Click({ Run-OfficeFullRepair })
$TeamsCleanButton.Add_Click({ Clean-TeamsCache })
$OutlookCacheCleanButton.Add_Click({ Clean-OutlookCache })

# Show GUI
$Window.ShowDialog() | Out-Null
