<#
.SYNOPSIS
    Windows Search Troubleshooter GUI for Windows 11 24H2.

.DESCRIPTION
    This PowerShell script provides a WPF GUI with buttons that run individual Windows Search troubleshooting steps
    based on Microsoft KB4520146. It helps restart services, check updates, run troubleshooters, restart search host,
    reset the search package, and clean registry/AppData.

.AUTHOR
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Fix Windows Search Tool v0.2"
        Height="480" Width="460"
        ResizeMode="CanMinimize"
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
        <TextBlock Text="Fix Windows Search Tool v0.2" FontSize="16" FontWeight="Bold" Margin="0,0,0,20" HorizontalAlignment="Center"/>
        <Button x:Name="BtnRestartFontCache" Content="Restart Font Cache Service"/>
        <Button x:Name="BtnCheckUpdates" Content="Check for Windows Updates"/>
        <Button x:Name="BtnRunTroubleshooter" Content="Run Search Troubleshooter"/>
        <Button x:Name="BtnRestartSearchHost" Content="Restart SearchHost.exe Process"/>
        <Button x:Name="BtnResetWindowsSearch" Content="Reset Windows Search Package"/>
        <Button x:Name="BtnCleanupRegistryAppData" Content="Clean Registry &amp; AppData"/>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="400" Minimum="0" Maximum="100" Margin="0,5,0,5" Value="0" Visibility="Collapsed"/>
        <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="black" Margin="10,10,10,0" HorizontalAlignment="Center"/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load UI
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Find controls
$progressBar = $window.FindName("ProgressBar")
$statusText = $window.FindName("StatusText")

$btnRestartFontCache = $window.FindName("BtnRestartFontCache")
$btnCheckUpdates = $window.FindName("BtnCheckUpdates")
$btnRunTroubleshooter = $window.FindName("BtnRunTroubleshooter")
$btnRestartSearchHost = $window.FindName("BtnRestartSearchHost")
$btnResetWindowsSearch = $window.FindName("BtnResetWindowsSearch")
$btnCleanupRegistryAppData = $window.FindName("BtnCleanupRegistryAppData")

function Update-UI {
    [System.Windows.Forms.Application]::DoEvents()
}

function Animate-ProgressBar {
    param ([int]$targetValue)
    while ($progressBar.Value -lt $targetValue) {
        $progressBar.Value++
        Start-Sleep -Milliseconds 20
        Update-UI
    }
}

function Ask-SearchCheck {
    [System.Windows.Forms.MessageBox]::Show(
        "Check if the Windows Search bar is working properly now.`nClick OK if yes, or Cancel to proceed to the next step.",
        "Check Search Bar",
        [System.Windows.Forms.MessageBoxButtons]::OKCancel,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
}

function Ask-Restart {
    [System.Windows.Forms.MessageBox]::Show(
        "It's recommended to restart your computer now for changes to take effect.`nRestart now?",
        "Restart Required",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
}

function Run-ActionWithProgress {
    param (
        [ScriptBlock]$Action,
        [string]$StartStatus,
        [string]$SuccessStatus,
        [System.Windows.Controls.Button]$ButtonToDisable,
        [switch]$AskRestartAfter
    )

    $ButtonToDisable.IsEnabled = $false
    $progressBar.Visibility = "Visible"
    $progressBar.Value = 0
    $statusText.Text = $StartStatus
    Update-UI

    # Start action as a background job
    $job = Start-Job -ScriptBlock $Action

    # Animate progress bar while job is running
    while ($job.State -eq 'Running') {
        if ($progressBar.Value -lt 90) {
            $progressBar.Value += 1
        }
        Start-Sleep -Milliseconds 50
        Update-UI
    }

    # Wait for job completion and collect errors if any
    $job | Wait-Job
    $errorResult = $job | Receive-Job -ErrorAction SilentlyContinue -ErrorVariable jobError
    Remove-Job $job

    if ($jobError) {
        $statusText.Text = "Error: $jobError"
    } else {
        Animate-ProgressBar -targetValue 100
        $statusText.Text = $SuccessStatus
    }

    $ButtonToDisable.IsEnabled = $true
    $progressBar.Visibility = "Collapsed"
    $progressBar.Value = 0
    Update-UI

    # Ask if search is working
    $result = Ask-SearchCheck
    if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
        $statusText.Text = "Please proceed to the next troubleshooting step."
    } else {
        $statusText.Text = "Search bar working."
    }

    if ($AskRestartAfter) {
        $restartResult = Ask-Restart
        if ($restartResult -eq [System.Windows.Forms.DialogResult]::Yes) {
            $statusText.Text = "Restarting computer..."
            Update-UI
            Start-Sleep -Seconds 1
            Restart-Computer -Force
        } else {
            $statusText.Text = "Restart canceled."
        }
    }
}

# --- Button Actions ---

$btnRestartFontCache.Add_Click({
    Run-ActionWithProgress -Action {
        Get-Service 'FontCache' -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Service 'FontCache' -ErrorAction SilentlyContinue
    } -StartStatus "Restarting Font Cache Service..." -SuccessStatus "Font Cache Service restarted." -ButtonToDisable $btnRestartFontCache
})

$btnCheckUpdates.Add_Click({
    Run-ActionWithProgress -Action {
        Start-Process -FilePath "UsoClient.exe" -ArgumentList "StartScan" -NoNewWindow -Wait
    } -StartStatus "Starting Windows Update scan..." -SuccessStatus "Windows Update scan started." -ButtonToDisable $btnCheckUpdates
})

$btnRunTroubleshooter.Add_Click({
    Run-ActionWithProgress -Action {
        Start-Process "msdt.exe" -ArgumentList "-ep WindowsHelp id SearchDiagnostic"
    } -StartStatus "Launching Search Troubleshooter..." -SuccessStatus "Troubleshooter launched." -ButtonToDisable $btnRunTroubleshooter
})

$btnRestartSearchHost.Add_Click({
    Run-ActionWithProgress -Action {
        $proc = Get-Process -Name "SearchHost" -ErrorAction SilentlyContinue
        if ($proc) { $proc | Stop-Process -Force }
    } -StartStatus "Restarting SearchHost.exe..." -SuccessStatus "SearchHost.exe restarted." -ButtonToDisable $btnRestartSearchHost
})

$btnResetWindowsSearch.Add_Click({
    Run-ActionWithProgress -Action {
        $originalPolicy = Get-ExecutionPolicy -Scope CurrentUser
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force
        $manifest = "C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\AppxManifest.xml"
        if (Test-Path $manifest) {
            Add-AppxPackage -Path $manifest -DisableDevelopmentMode -Register
        }
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy $originalPolicy -Force
    } -StartStatus "Resetting Search package..." -SuccessStatus "Windows Search package reset." -ButtonToDisable $btnResetWindowsSearch -AskRestartAfter
})

$btnCleanupRegistryAppData.Add_Click({
    Run-ActionWithProgress -Action {
        $appData = "$env:LOCALAPPDATA\Packages\MicrosoftWindows.Client.CBS_cw5n1h2txyewy"
        if (Test-Path $appData) {
            Remove-Item -Path $appData -Recurse -Force -ErrorAction SilentlyContinue
        }
        $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
        if (Test-Path $regKey) {
            Remove-Item -Path $regKey -Recurse -Force -ErrorAction SilentlyContinue
        }
    } -StartStatus "Cleaning Registry and AppData..." -SuccessStatus "Cleanup complete." -ButtonToDisable $btnCleanupRegistryAppData -AskRestartAfter
})

# Show Window
$window.ShowDialog() | Out-Null
