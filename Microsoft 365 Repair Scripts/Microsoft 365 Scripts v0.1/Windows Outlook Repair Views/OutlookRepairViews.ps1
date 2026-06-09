<#
.TITLE
    Reset Microsoft Outlook Views - WPF GUI

.SYNOPSIS
    Closes Microsoft Outlook and resets all customized views using the /cleanviews switch.

.DESCRIPTION
    This script uses WPF for a graphical interface. It checks for Outlook, closes any active
    Outlook processes, and launches Outlook with the /cleanviews argument to reset all user views.
    A progress bar visualizes the steps. Requires admin rights.

.NOTES
    Author       : Allester Padovani
    Title        : Senior IT Professional
    Script Ver.  : 1.1
    Date         : 2025-07-19
    Compatibility: Windows 10/11, Outlook 2013 and above
    Requirements : Local admin rights (to kill Outlook process if needed)
#>

# Ensure script is running as admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# WASAPI-Style XAML UI
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Reset Outlook Views'
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
        <TextBlock Text='Reset Microsoft Outlook Views' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='ResetButton' Content='Reset Outlook Views'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Value='0' Margin='0,5,0,5'/>
        <TextBlock x:Name='StatusText' Text='' FontSize='12' Foreground='black' HorizontalAlignment='Center' Margin='0,10,0,10'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.'
                   FontSize='12' FontStyle='Italic' Foreground='black' HorizontalAlignment='Center' Margin='0,20,0,0'/>
    </StackPanel>
</Window>
"@

# Load WPF window
[xml]$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDoc.LoadXml($xaml)
$reader = New-Object System.Xml.XmlNodeReader $xmlDoc
$window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$ResetButton = $window.FindName("ResetButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText  = $window.FindName("StatusText")

function Do-Events { [System.Windows.Forms.Application]::DoEvents() }

# Progress Helper
function Update-Progress {
    param ([string]$Message, [int]$TargetValue)
    $StatusText.Text = $Message
    for ($i = $ProgressBar.Value; $i -lt $TargetValue; $i++) {
        $ProgressBar.Value = $i
        Do-Events
        Start-Sleep -Milliseconds 25
    }
}

# Get Outlook EXE Path
function Get-OutlookPath {
    $paths = @(
        "$env:ProgramFiles\Microsoft Office\root\Office16\OUTLOOK.EXE",
        "$env:ProgramFiles(x86)\Microsoft Office\root\Office16\OUTLOOK.EXE",
        "$env:ProgramFiles\Microsoft Office\Office16\OUTLOOK.EXE",
        "$env:ProgramFiles(x86)\Microsoft Office\Office16\OUTLOOK.EXE",
        "$env:ProgramFiles\Microsoft Office\Office15\OUTLOOK.EXE",
        "$env:ProgramFiles(x86)\Microsoft Office\Office15\OUTLOOK.EXE"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) { return $path }
    }
    $cmd = Get-Command outlook.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

# Main Reset Logic
$ResetButton.Add_Click({
    $ResetButton.IsEnabled = $false

    $outlookPath = Get-OutlookPath
    if (-not $outlookPath) {
        [System.Windows.MessageBox]::Show("Outlook.exe not found. Please ensure Outlook is installed.", "Outlook Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        $window.Close()
        return
    }

    Update-Progress -Message "Checking for Outlook process..." -TargetValue 20
    Get-Process outlook -ErrorAction SilentlyContinue | ForEach-Object {
        $StatusText.Text = "Terminating Outlook (PID: $($_.Id))..."
        $_.Kill()
        Do-Events
    }

    Update-Progress -Message "Waiting for Outlook to close..." -TargetValue 40
    Start-Sleep -Seconds 3

    Update-Progress -Message "Launching Outlook with /cleanviews..." -TargetValue 70
    Start-Process -FilePath $outlookPath -ArgumentList "/cleanviews"
    Start-Sleep -Seconds 2

    Update-Progress -Message "Operation complete. Outlook views reset." -TargetValue 100
    $StatusText.Text = "Done. You may close this window."

    [System.Windows.MessageBox]::Show("Outlook views have been reset successfully.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    $window.Close()
})

# Show the GUI
$window.ShowDialog() | Out-Null
