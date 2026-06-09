<#
.SYNOPSIS
    WPF GUI for updating audio drivers on Windows 11.

.DESCRIPTION
    This script provides a graphical user interface (GUI) for updating the audio drivers on a Windows 11 system. The user can start the update process 
    by clicking a button, which will trigger the update of audio drivers for all devices with a status of "OK". The progress of the update is shown through 
    a progress bar, and the user is notified upon completion or if an error occurs.

    The script checks for administrative privileges before proceeding. If the script is not run with administrative rights, it will display a warning and exit.
    In case no audio devices with status "OK" are found, the user will be informed through a message box.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2  
    Requirements : Admin rights, .NET Framework (for WPF and WinForms)
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
        Title='Audio Driver Update'
        Height='430' Width='460'
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
            <Setter Property='Height' Value='30'/>
            <Setter Property='Margin' Value='0,0,0,10'/>
        </Style>
    </Window.Resources>
    <StackPanel Margin='20' HorizontalAlignment='Center'>
        <TextBlock Text='Update Audio Drivers' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='UpdateAudioButton' Content='Start Update'/>
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
$UpdateAudioButton = $window.FindName("UpdateAudioButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Define the logic for updating audio drivers
$UpdateAudioButton.Add_Click({
    try {
        # Check for Administrator privileges
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
            [Security.Principal.WindowsBuiltInRole] "Administrator")) {
            [System.Windows.Forms.MessageBox]::Show(
                "This script must be run as Administrator.",
                "Insufficient Privileges",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            exit
        }

        # Get all audio devices with status OK
        $audioDevices = Get-PnpDevice -Class Media -Status OK

        if ($audioDevices.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "No audio devices found with status OK.",
                "No Devices",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information)
            exit
        }

        $total = $audioDevices.Count
        $counter = 0

        # Start updating audio drivers
        foreach ($device in $audioDevices) {
            $counter++
            $percent = [math]::Round(($counter / $total) * 100)
            $ProgressBar.Value = $percent
            $StatusText.Text = "Updating audio driver $counter of $total... $percent% completed."

            try {
                pnputil /update-driver $device.InstanceId /install | Out-Null
            }
            catch {
                # Optionally log or handle errors here
                $StatusText.Text = "Error updating driver: $($_.Exception.Message)"
            }
        }

        # Notify user of completion
        $StatusText.Text = "Audio drivers update process completed."
        $ProgressBar.Value = 100
        [System.Windows.Forms.MessageBox]::Show(
            "Audio drivers update process completed successfully.",
            "Audio Drivers Update",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information)

    } catch {
        # General error handling
        $StatusText.Text = "An error occurred during the update process."
        $ProgressBar.Value = 100
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred during the update process:`n$_",
            "Audio Drivers Update Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# Show the window
$window.ShowDialog()
