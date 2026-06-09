<#
.SYNOPSIS
    Runs a silent full repair of Microsoft Office using OfficeClickToRun.exe, ensuring the script runs with administrator privileges.

.DESCRIPTION
    This script checks if it is running with elevated Administrator rights and, if not, restarts itself with elevated privileges.
    It then silently launches the Microsoft Office full repair process with appropriate command-line arguments.
    A WPF-based GUI shows a progress bar and provides visual confirmation of the repair initiation.

.NOTES
    - Requires Administrator privileges to launch Office repair.
    - Compatible with Windows 11 24H2 and later.
    - Uses Start-Process with silent parameters.
    - Provides user feedback via GUI and message box.
    - Adjust the OfficeClickToRun.exe path and arguments if needed for other versions or languages.

.AUTHOR
    Name        : Allester Padovani
    Title       : Senior IT Specialist
    Date        : 2025-07-18
#>

# Admin elevation check
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    $psi.WindowStyle = "Hidden"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}

# Load assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# XAML layout with WASAPI style
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Office Full Repair'
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
        <TextBlock Text='Run Microsoft Office Full Repair' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='RepairButton' Content='Run Office Full Repair'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='' FontSize='12' Foreground='black' HorizontalAlignment='Center' Margin='0,10,0,10'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML window
[xml]$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDoc.LoadXml($xaml)
$reader = New-Object System.Xml.XmlNodeReader $xmlDoc
$window = [Windows.Markup.XamlReader]::Load($reader)

# Find controls
$RepairButton = $window.FindName("RepairButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# DoEvents helper
function Do-Events { [System.Windows.Forms.Application]::DoEvents() }

# Smooth progress update helper
function Update-Progress {
    param([string]$Message, [int]$Target)
    $StatusText.Text = $Message
    for ($i = $ProgressBar.Value; $i -lt $Target; $i++) {
        $ProgressBar.Value = $i
        Do-Events
        Start-Sleep -Milliseconds 15
    }
}

# Repair button click
$RepairButton.Add_Click({

    $RepairButton.IsEnabled = $false
    Update-Progress -Message "Preparing repair..." -Target 25

    $clickToRunPath = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    if (-not (Test-Path $clickToRunPath)) {
        [System.Windows.Forms.MessageBox]::Show("OfficeClickToRun.exe not found.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $window.Close()
        return
    }

    Update-Progress -Message "Launching Office Full Repair..." -Target 60

    Start-Process -FilePath $clickToRunPath `
        -ArgumentList "scenario=Repair platform=x64 culture=en-us forceappshutdown=True RepairType=FullRepair DisplayLevel=True" `
        -WindowStyle Hidden

    Start-Sleep -Seconds 5
    Update-Progress -Message "Repair process started." -Target 100

    $StatusText.Text = "Repair started successfully."

    [System.Windows.Forms.MessageBox]::Show(
        "Microsoft Office Full Repair has been initiated. You may continue using your computer.",
        "Repair Started",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    $window.Close()
})

# Show window
$window.ShowDialog() | Out-Null
