<#
.SYNOPSIS
    Checks for administrator privileges and initiates a Microsoft Office Quick Repair silently.

.DESCRIPTION
    The script verifies if it is running with administrator rights, and if not, it relaunches itself with elevated privileges.
    It then starts the OfficeClickToRun.exe repair process using the Quick Repair option silently in the background.
    After initiating the repair, it informs the user via a Windows Forms message box that the repair has started.

.NOTES
    Author       : Allester Padovani
    Title        : Senior IT Specialist
    Date         : 2025-07-18
    Version      : 1.0
    Compatible   : Windows 11 24H2 and later
    Requirements : Admin rights, OfficeClickToRun installed, WPF support
#>

# Elevation check
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = $args
    $psi.Verb = "runas"
    $psi.WindowStyle = "Hidden"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}

# Load required assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# WASAPI style XAML layout
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Office Quick Repair'
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
        <TextBlock Text='Start Microsoft Office Quick Repair' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='RepairButton' Content='Run Office Quick Repair'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Value='0' Margin='0,5,0,5'/>
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

# Access controls
$RepairButton = $window.FindName("RepairButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# DoEvents helper for UI responsiveness
function Do-Events { [System.Windows.Forms.Application]::DoEvents() }

# Smooth progress bar update
function Update-Progress {
    param([string]$Message, [int]$Target)
    $StatusText.Text = $Message
    for ($i = $ProgressBar.Value; $i -lt $Target; $i++) {
        $ProgressBar.Value = $i
        Do-Events
        Start-Sleep -Milliseconds 15
    }
}

# Repair button click handler
$RepairButton.Add_Click({
    $RepairButton.IsEnabled = $false

    Update-Progress -Message "Preparing to start repair..." -Target 25

    $clickToRunPath = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
    if (-not (Test-Path $clickToRunPath)) {
        [System.Windows.MessageBox]::Show("OfficeClickToRun.exe not found. Please verify Microsoft Office is installed.", "Error", "OK", "Error")
        $window.Close()
        return
    }

    Update-Progress -Message "Launching Office Quick Repair..." -Target 60

    Start-Process -FilePath $clickToRunPath `
        -ArgumentList "scenario=Repair platform=x64 culture=en-us forceappshutdown=True RepairType=QuickRepair DisplayLevel=True" `
        -WindowStyle Hidden

    Start-Sleep -Seconds 5
    Update-Progress -Message "Repair process started." -Target 100
    $StatusText.Text = "Office repair launched successfully."

    [System.Windows.MessageBox]::Show("Microsoft Office repair has been initiated. You may continue using your computer.", "Repair Started", "OK", "Information")
    $window.Close()
})

# Show window
$window.ShowDialog() | Out-Null
