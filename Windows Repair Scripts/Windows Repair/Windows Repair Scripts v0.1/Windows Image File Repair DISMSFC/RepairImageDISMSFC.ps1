<#
.SYNOPSIS
    System Repair Utility to run DISM and SFC tools with a user-friendly GUI.

.DESCRIPTION
    This script performs system repair by utilizing the DISM and SFC tools to repair system image and fix file corruption.
    It provides real-time progress feedback through a WPF GUI interface and logs the results to disk.
    It is designed to be run with Administrator privileges.

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

# Define XAML layout
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='System Repair Utility'
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
        <TextBlock Text='System Repair Utility' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='RunButton' Content='Start System Repair'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

$RunButton = $window.FindName("RunButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

function Update-UI {
    [System.Windows.Forms.Application]::DoEvents()
}

$dismLogFolder = "C:\ProgramData\OzarkTechTeam\DISM tool Logs"
$sfcLogFolder = "C:\ProgramData\OzarkTechTeam\SFC Logs"
$dismLogFile = Join-Path $dismLogFolder "DISM_log.txt"
$sfcLogFile = Join-Path $sfcLogFolder "SFC_log.txt"

if (-not (Test-Path $dismLogFolder)) { New-Item -Path $dismLogFolder -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $sfcLogFolder)) { New-Item -Path $sfcLogFolder -ItemType Directory -Force | Out-Null }

$RunButton.Add_Click({
    $RunButton.IsEnabled = $false

    $dismSteps = @(
        @{ Description = "Checking image health (DISM)..."; Cmd = { dism.exe /Online /Cleanup-Image /CheckHealth | Out-File -FilePath $dismLogFile -Append }; Progress = 30 },
        @{ Description = "Scanning image health (DISM)..."; Cmd = { dism.exe /Online /Cleanup-Image /ScanHealth | Out-File -FilePath $dismLogFile -Append }; Progress = 60 },
        @{ Description = "Restoring image health (DISM)..."; Cmd = { dism.exe /Online /Cleanup-Image /RestoreHealth | Out-File -FilePath $dismLogFile -Append }; Progress = 100 }
    )

    "Starting DISM tool at $(Get-Date)" | Out-File -FilePath $dismLogFile -Append

    foreach ($step in $dismSteps) {
        $StatusText.Text = "{0} {1}%" -f $step.Description, $step.Progress
        $ProgressBar.Value = $step.Progress
        Update-UI
        try {
            & $step.Cmd
            "$($step.Description) succeeded at $(Get-Date)" | Out-File -FilePath $dismLogFile -Append
        } catch {
            "Error during $($step.Description): $_" | Out-File -FilePath $dismLogFile -Append
        }
    }

    "DISM process completed at $(Get-Date)`r`n" | Out-File -FilePath $dismLogFile -Append

    $StatusText.Text = "Starting System File Checker (SFC)..."
    $ProgressBar.Value = 0
    Update-UI

    "Starting SFC at $(Get-Date)" | Out-File -FilePath $sfcLogFile -Append

    try {
        $StatusText.Text = "Running System File Checker (SFC)... 50%"
        $ProgressBar.Value = 50
        Update-UI
        sfc.exe /scannow | Out-File -FilePath $sfcLogFile -Append
        "SFC scan completed at $(Get-Date)" | Out-File -FilePath $sfcLogFile -Append
        $ProgressBar.Value = 100
        $StatusText.Text = "System File Checker (SFC) completed. 100%"
        Update-UI
    } catch {
        "Error during SFC scan: $_" | Out-File -FilePath $sfcLogFile -Append
    }

    $RunButton.IsEnabled = $true
})

[void]$window.ShowDialog()
