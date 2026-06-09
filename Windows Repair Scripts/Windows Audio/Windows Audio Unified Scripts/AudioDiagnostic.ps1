<#
.SYNOPSIS
    A comprehensive audio diagnostic and management tool for Windows, designed to manage audio devices, restart audio services, update drivers, and provide quick access to common audio settings. This tool also allows the user to uninstall audio devices and restart the WASAPI service with elevated privileges.

.DESCRIPTION
    This script provides a graphical user interface (GUI) built using WPF (Windows Presentation Foundation) to interact with system audio settings. It includes the following key functionalities:
    - Uninstall audio devices (with automatic reinstallation after a system scan).
    - Restart core audio services (`AudioEndpointBuilder` and `Audiosrv`).
    - Update audio drivers for all active audio devices.
    - Access various audio settings such as the Volume Mixer, Sound Settings, Microphone Privacy Settings, Classic Sound Control Panel, and Playback Devices.
    - Restart the WASAPI AudioEndpointBuilder service to troubleshoot audio issues.
    - Provides real-time progress feedback and status updates throughout each operation.

    The script checks for administrative privileges, ensures the user is an administrator, and relaunches the script with elevated rights if needed.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2 
    Requirements : Admin rights, Outlook installed, .NET Framework (for WPF and WinForms)

    Changes in Version 1.0:
    - Initial release of the tool.
    - Added full set of functionalities for managing and diagnosing audio devices.
    - Implemented GUI-based controls using WPF.

#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Check if the script is running with admin rights
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # If not running as admin, relaunch the script as Administrator
    $args = [System.Environment]::GetCommandLineArgs()
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
        FileName = $args[0]
        Verb     = "runas"  # This will request elevated privileges
        Arguments = ($args[1..$args.Length] -join " ")  # Pass the remaining arguments
    }
    [System.Diagnostics.Process]::Start($startInfo)
    exit
}

# Load the necessary WPF libraries
Add-Type -AssemblyName PresentationCore, PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Audio Diagnostic &amp; Health Check Tool"
        Height="500" Width="460"
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
        <TextBlock Text="Audio Diagnostic &amp; Health Check Tool" FontSize="16" FontWeight="Bold" Margin="0,0,0,20"
                   HorizontalAlignment="Center"/>
        <Button x:Name="UninstallAudioDevicesButton" Content="Uninstall Audio Devices"/>
        <Button x:Name="RestartAudioServicesButton" Content="Restart Audio Services"/>
        <Button x:Name="UpdateAudioDriversButton" Content="Update Audio Drivers"/>
        <Button x:Name="OpenVolumeMixerButton" Content="Open Volume Mixer"/>
        <Button x:Name="OpenSoundSettingsButton" Content="Open Sound Settings"/>
        <Button x:Name="OpenMicrophonePrivacyButton" Content="Open Microphone Privacy Settings"/>
        <Button x:Name="OpenClassicSoundControlButton" Content="Open Classic Sound Control Panel"/>
        <Button x:Name="OpenPlaybackDevicesButton" Content="Open Playback Devices (Volume Mixer)"/>
        <Button x:Name="RestartWASAPIButton" Content="Restart WASAPI Service"/>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="400" Minimum="0" Maximum="100" Margin="0,5,0,5" Value="0"/>
        <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="black"/>
        <TextBlock Text=" Allester Padovani, Senior IT Specialist. All rights reserved." FontSize="12" FontStyle="Italic" Foreground="black" Margin="0,20,0,0" HorizontalAlignment="Center"/>
    </StackPanel>
</Window>
"@

# Load XAML into the PowerShell object
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get the controls
$uninstallAudioDevicesButton = $window.FindName("UninstallAudioDevicesButton")
$restartAudioServicesButton = $window.FindName("RestartAudioServicesButton")
$updateAudioDriversButton = $window.FindName("UpdateAudioDriversButton")
$openVolumeMixerButton = $window.FindName("OpenVolumeMixerButton")
$openSoundSettingsButton = $window.FindName("OpenSoundSettingsButton")
$openMicrophonePrivacyButton = $window.FindName("OpenMicrophonePrivacyButton")
$openClassicSoundControlButton = $window.FindName("OpenClassicSoundControlButton")
$openPlaybackDevicesButton = $window.FindName("OpenPlaybackDevicesButton")
$restartWASAPIButton = $window.FindName("RestartWASAPIButton")
$progressBar = $window.FindName("ProgressBar")
$statusText = $window.FindName("StatusText")

# Function to reset the progress bar after an operation
function Reset-ProgressBar {
    $progressBar.Value = 0
    $statusText.Text = "Ready."
}

# Function for uninstalling audio devices with live progress update
$uninstallAudioDevicesButton.Add_Click({
    # Get the list of active audio devices
    $audioDevices = Get-PnpDevice -Class Media -Status OK

    # Show a confirmation dialog box
    $userConfirm = [System.Windows.MessageBox]::Show("This will uninstall all active audio devices. Windows will reinstall them automatically after a scan. Do you want to continue?", "Confirm Action", [System.Windows.MessageBoxButton]::YesNo)

    if ($userConfirm -ne [System.Windows.MessageBoxResult]::Yes) {
        $statusText.Text = "Operation canceled by user."
        Reset-ProgressBar
        return
    }

    $failedUninstalls = @()
    $progressBar.Value = 0
    $statusText.Text = "Uninstalling audio devices..."

    $total = $audioDevices.Count
    $counter = 0

    foreach ($device in $audioDevices) {
        $counter++
        $percent = [math]::Round(($counter / $total) * 100)
        $progressBar.Value = $percent
        $statusText.Text = "Uninstalling: $($device.FriendlyName)"

        try {
            pnputil /remove-device "$($device.InstanceId)" | Out-Null
            Start-Sleep -Seconds 2
        } catch {
            Write-Warning "Failed to uninstall: $($device.FriendlyName)"
            $failedUninstalls += $device.FriendlyName
        }
    }

    # Rescan devices
    try {
        Start-Process -FilePath "pnputil.exe" -ArgumentList "/scan-devices" -Wait
    } catch {
        Write-Warning "Device rescan failed: $_"
    }

    $progressBar.Value = 100

    if ($failedUninstalls.Count -eq 0) {
        $statusText.Text = "Audio devices uninstalled successfully. Windows will reinstall the drivers automatically. A system reboot may be required."
    } else {
        $failList = $failedUninstalls -join "`n"
        $statusText.Text = "Some devices could not be uninstalled."
        [System.Windows.MessageBox]::Show("The following devices could not be uninstalled:`n`n$failList`n`nPlease uninstall them manually or contact IT support.", "Uninstall Failed", [System.Windows.MessageBoxButton]::OK)
    }

    Reset-ProgressBar
})

# Function to restart audio services with live progress update
$restartAudioServicesButton.Add_Click({
    # List of audio services to restart
    $services = @("AudioEndpointBuilder", "Audiosrv")
    $total = $services.Count
    $counter = 0
    $statusText.Text = "Restarting audio services..."
    $progressBar.Value = 0

    foreach ($service in $services) {
        $counter++
        $percent = [math]::Round(($counter / $total) * 100)
        $progressBar.Value = $percent
        $statusText.Text = "Restarting: $service"

        try {
            Restart-Service -Name $service -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to restart the service '$service'.`nError details: $($_.Exception.Message)", "Service Restart Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            Reset-ProgressBar
            return
        }
    }

    [System.Windows.Forms.MessageBox]::Show("Audio services have been restarted successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    $progressBar.Value = 100
    $statusText.Text = "Audio services restarted."
    Reset-ProgressBar
})

# Function to update audio drivers with live progress update
$updateAudioDriversButton.Add_Click({
    # Get the list of audio devices
    $audioDevices = Get-PnpDevice -Class Media -Status OK

    if ($audioDevices.Count -eq 0) {
        Reset-ProgressBar
        return
    }

    $total = $audioDevices.Count
    $counter = 0
    $statusText.Text = "Updating Audio Drivers..."
    $progressBar.Value = 0

    foreach ($device in $audioDevices) {
        $counter++
        $percent = [math]::Round(($counter / $total) * 100)
        $progressBar.Value = $percent
        $statusText.Text = "Updating driver for: $($device.FriendlyName)"

        pnputil /update-driver $device.InstanceId /install | Out-Null
        Start-Sleep -Seconds 1
    }

    $progressBar.Value = 100
    $statusText.Text = "Audio drivers updated."
    Reset-ProgressBar
})

# Function to open the Volume Mixer
$openVolumeMixerButton.Add_Click({
    $statusText.Text = "Opening Volume Mixer..."
    $progressBar.Value = 50
    Start-Process "ms-settings:apps-volume"
    $progressBar.Value = 100
    Reset-ProgressBar
})

# Function to open Sound Settings
$openSoundSettingsButton.Add_Click({
    $statusText.Text = "Opening Sound Settings..."
    $progressBar.Value = 50
    Start-Process "ms-settings:sound"
    $progressBar.Value = 100
    Reset-ProgressBar
})

# Function to open Microphone Privacy Settings
$openMicrophonePrivacyButton.Add_Click({
    $statusText.Text = "Opening Microphone Privacy Settings..."
    $progressBar.Value = 50
    Start-Process "ms-settings:privacy-microphone"
    $progressBar.Value = 100
    Reset-ProgressBar
})

# Function to open Classic Sound Control Panel
$openClassicSoundControlButton.Add_Click({
    $statusText.Text = "Opening Classic Sound Control Panel..."
    $progressBar.Value = 50
    Start-Process "mmsys.cpl"
    $progressBar.Value = 100
    Reset-ProgressBar
})

# Function to open Playback Devices
$openPlaybackDevicesButton.Add_Click({
    $statusText.Text = "Opening Playback Devices..."
    $progressBar.Value = 50
    Start-Process "sndvol.exe"
    $progressBar.Value = 100
    Reset-ProgressBar
})

# Function to restart WASAPI service
$restartWASAPIButton.Add_Click({
    Restart-Service -Name "AudioEndpointBuilder" -Force
    Write-Host "WASAPI Service Restarted"
    $progressBar.Value = 100
    [System.Windows.Forms.MessageBox]::Show("WASAPI AudioEndpointBuilder Service has been restarted successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    Reset-ProgressBar
})

# Show the window
$window.ShowDialog()
