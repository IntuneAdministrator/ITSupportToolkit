<#
.SYNOPSIS
    A GUI to manage and troubleshoot WASAPI audio settings on Windows.

.DESCRIPTION
    This script creates a WPF-based graphical user interface (GUI) for managing and troubleshooting WASAPI audio settings on Windows.
    It allows the user to:
    - Open the Volume Mixer (App Volume & Device Preferences).
    - Open Sound Settings.
    - Open Microphone Privacy Settings.
    - Open the Classic Sound Control Panel.
    - Open Playback Devices (Classic Volume Mixer).
    - Restart the WASAPI service (AudioEndpointBuilder).

    The script provides a visual progress bar to guide the user through each operation, with status updates shown in a text field.

    It also checks for Administrator privileges when attempting to restart the WASAPI service and informs the user if admin rights are required.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2
    Requirements : Admin rights (for restarting WASAPI service), .NET Framework (for WPF and WinForms)
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load necessary assemblies for WPF and Windows Forms
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define the XAML layout for the UI
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='WASAPI Audio Dashboard'
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
        <TextBlock Text='WASAPI Audio Dashboard' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='OpenVolumeMixerButton' Content='Open Volume Mixer'/>
        <Button x:Name='OpenSoundSettingsButton' Content='Open Sound Settings'/>
        <Button x:Name='OpenMicrophoneSettingsButton' Content='Open Microphone Settings'/>
        <Button x:Name='OpenControlPanelButton' Content='Open Classic Control Panel'/>
        <Button x:Name='OpenPlaybackDevicesButton' Content='Open Playback Devices'/>
        <Button x:Name='RestartWASAPIServiceButton' Content='Restart WASAPI Service'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML into a Window object
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get UI elements
$OpenVolumeMixerButton = $window.FindName("OpenVolumeMixerButton")
$OpenSoundSettingsButton = $window.FindName("OpenSoundSettingsButton")
$OpenMicrophoneSettingsButton = $window.FindName("OpenMicrophoneSettingsButton")
$OpenControlPanelButton = $window.FindName("OpenControlPanelButton")
$OpenPlaybackDevicesButton = $window.FindName("OpenPlaybackDevicesButton")
$RestartWASAPIServiceButton = $window.FindName("RestartWASAPIServiceButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Function to update the progress bar
function Update-ProgressBar {
    param (
        [Parameter(Mandatory=$true)]
        [int]$value
    )
    $ProgressBar.Value = $value
}

# Function to open Volume Mixer
$OpenVolumeMixerButton.Add_Click({
    Update-ProgressBar -value 20
    Start-Process "ms-settings:apps-volume"
    $StatusText.Text = "Opened Volume Mixer (App Volume & Device Preferences)"
    Update-ProgressBar -value 100
})

# Function to open Sound Settings
$OpenSoundSettingsButton.Add_Click({
    Update-ProgressBar -value 20
    Start-Process "ms-settings:sound"
    $StatusText.Text = "Opened Sound Settings"
    Update-ProgressBar -value 100
})

# Function to open Microphone Settings
$OpenMicrophoneSettingsButton.Add_Click({
    Update-ProgressBar -value 20
    Start-Process "ms-settings:privacy-microphone"
    $StatusText.Text = "Opened Microphone Privacy Settings"
    Update-ProgressBar -value 100
})

# Function to open Classic Control Panel
$OpenControlPanelButton.Add_Click({
    Update-ProgressBar -value 20
    Start-Process "mmsys.cpl"
    $StatusText.Text = "Opened Classic Sound Control Panel"
    Update-ProgressBar -value 100
})

# Function to open Playback Devices
$OpenPlaybackDevicesButton.Add_Click({
    Update-ProgressBar -value 20
    Start-Process "sndvol.exe"
    $StatusText.Text = "Opened Playback Devices (Classic Volume Mixer)"
    Update-ProgressBar -value 100
})

# Function to restart the WASAPI service
$RestartWASAPIServiceButton.Add_Click({
    Update-ProgressBar -value 20
    # Admin check
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")) {
        $StatusText.Text = "This action requires Administrator privileges."
        Update-ProgressBar -value 100
        return
    }

    # Restart WASAPI service
    try {
        Restart-Service -Name "AudioEndpointBuilder" -Force -ErrorAction Stop
        $StatusText.Text = "The WASAPI AudioEndpointBuilder service has been successfully restarted."
    } catch {
        $StatusText.Text = "Failed to restart the WASAPI service."
    }
    Update-ProgressBar -value 100
})

# Show the window
$window.ShowDialog()
