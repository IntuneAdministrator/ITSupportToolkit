<#
.SYNOPSIS
    This script provides a graphical user interface (GUI) for updating webcam drivers on a Windows system.
    It checks for installed webcams, verifies if the drivers need an update, and attempts to update them using Windows utilities.

.DESCRIPTION
    This script offers an easy-to-use GUI for webcam driver updates. Users can click a button to initiate the update process. 
    The script scans for installed webcams, checks for driver updates, and attempts to update the drivers if necessary. 
    It provides progress feedback through a progress bar and displays a status message indicating the current operation.
    
    If the webcam drivers are already up-to-date, the script will inform the user. If a driver update fails, an error message is shown.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2
    Requirements : Admin rights, Outlook installed, .NET Framework (for WPF and WinForms), PowerShell 7+
    
    This script uses the `pnputil` tool for updating drivers, and requires appropriate permissions to install drivers on the system.
    It will work on any system with a compatible version of Windows and requires the user to have administrative privileges.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load necessary assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define the XAML layout
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Webcam Driver Update"
        Height="430" Width="460"
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
        <TextBlock Text="Webcam Driver Update" FontSize="16" FontWeight="Bold" Margin="0,0,0,20"
                   HorizontalAlignment="Center"/>
        <Button x:Name="UpdateDriversButton" Content="Update Webcam Drivers"/>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="400" Minimum="0" Maximum="100" Margin="0,5,0,5" Value="0"/>
        <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="black"/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get UI elements
$UpdateDriversButton = $window.FindName("UpdateDriversButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Define the logic to update the webcam drivers
$UpdateDriversButton.Add_Click({
    # Gather all enabled webcams (camera and media devices)
    $cameras = Get-PnpDevice -Class "Camera" -Status OK -ErrorAction SilentlyContinue
    $mediaDevices = Get-PnpDevice -Class "Media" -Status OK -ErrorAction SilentlyContinue

    # Combine devices
    $allDevices = @()
    if ($cameras) { $allDevices += $cameras }
    if ($mediaDevices) { $allDevices += $mediaDevices }

    # Filter webcams
    $webcams = $allDevices | Where-Object { $_.FriendlyName -match 'camera|webcam' }

    # Handle no webcams found
    if (-not $webcams) {
        $StatusText.Text = "No enabled webcam devices found."
        $ProgressBar.Value = 100
        return
    }

    # Process webcam drivers
    $totalWebcams = $webcams.Count
    $updatedCount = 0
    $StatusText.Text = "Checking for driver updates..."

    # Reset progress bar
    $ProgressBar.Value = 1

    # Check if totalWebcams is zero to avoid divide by zero error
    if ($totalWebcams -eq 0) {
        $StatusText.Text = "No webcams found to update."
        $ProgressBar.Value = 100
        return
    }

    # Loop through each webcam device and update
    foreach ($device in $webcams) {
        try {
            # Capture the current driver version before updating
            $currentDriverVersion = (Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName "DEVPKEY_Device_DriverVersion").Data

            # Check for the latest driver using pnputil
            $result = & "$env:SystemRoot\System32\pnputil.exe" /update-driver "$($device.InstanceId)" /install

            # Capture the driver version after attempting the update
            $updatedDriverVersion = (Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName "DEVPKEY_Device_DriverVersion").Data

            # Check if the driver was actually updated
            if ($currentDriverVersion -eq $updatedDriverVersion) {
                # If the driver version didn't change, it was already up to date
                $StatusText.Text = "$($device.FriendlyName) driver is already updated."
            } else {
                # If the driver version changed, it was updated
                $StatusText.Text = "Webcam driver is updating..."
                $updatedCount++
            }
        }
        catch {
            # Handle errors if the driver update fails
            $StatusText.Text = "Failed to update driver for: $($device.FriendlyName). Error: $_"
        }

        # Ensure the progress bar is still active (even if no update)
        $ProgressBar.Value = 100
    }

    # Final status message
    if ($updatedCount -eq 0) {
        $StatusText.Text = "Webcam driver is already updated."
    }
    elseif ($updatedCount -eq $totalWebcams) {
        $StatusText.Text = "All drivers updated successfully."
    }
    else {
        $StatusText.Text = "$updatedCount out of $totalWebcams drivers updated."
    }

    # Ensure the progress bar reaches 100% after process ends
    $ProgressBar.Value = 100
})

# Show window
$window.ShowDialog()
