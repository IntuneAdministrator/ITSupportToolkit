<#
.SYNOPSIS
    A tool to restart webcam devices on a Windows system. This script provides a graphical interface to restart detected webcam devices by disabling and enabling them via Device Manager.

.DESCRIPTION
    This PowerShell script uses a graphical user interface (GUI) to restart all connected webcam devices on a Windows system. It works by:
    - Querying the system for all webcam devices using CIM/WMI.
    - Disabling and then re-enabling each detected webcam device via the `Disable-PnpDevice` and `Enable-PnpDevice` cmdlets.
    - Updating the user interface with a progress bar that tracks the restarting process for each webcam.
    - Notifying the user upon completion or if no devices are found.

    The script is designed for ease of use, providing the following functionality:
    - A progress bar to visualize the restart operation.
    - Status messages indicating the success or failure of the operation.
    - Error handling in case of issues such as no webcam being found, or problems restarting devices.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2  
    Requirements : Admin rights, .NET Framework (for WPF), appropriate permissions to disable and enable devices.
    
    Changes in Version 1.0:
    - Initial release of the tool.
    - Implements functionality to restart webcam devices by disabling and enabling them.
    - Provides a progress bar and user-friendly status messages.
    - Includes error handling for failed attempts to restart devices.
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
        Title='Webcam Restart'
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
            <Setter Property='Height' Value='20'/>
            <Setter Property='Margin' Value='0,0,0,10'/>
        </Style>
    </Window.Resources>
    <StackPanel Margin='20' HorizontalAlignment='Center'>
        <TextBlock Text='Restart Webcam Devices' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='RestartWebcamsButton' Content='Restart Webcams'/>
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
$RestartWebcamsButton = $window.FindName("RestartWebcamsButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Define the logic for restarting the webcam devices
$RestartWebcamsButton.Add_Click({
    try {
        # Get webcam devices (exclude printers and scanners)
        $webcams = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_PnPEntity | Where-Object {
            ($_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image') -and
            ($_.Name -notmatch 'Printer|OfficeJet|Fax|Scan|Copy')
        }

        if (-not $webcams) {
            # No webcams found
            [System.Windows.Forms.MessageBox]::Show(
                "No webcam devices found to restart.",
                "No Devices Detected",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            $StatusText.Text = "No webcams found."
            $ProgressBar.Value = 100
            return
        }

        # Initialize progress bar and status text
        $ProgressBar.Value = 0
        $StatusText.Text = "Restarting webcam devices..."

        # Safeguard to prevent divide by zero
        $totalWebcams = $webcams.Count
        if ($totalWebcams -eq 0) {
            $StatusText.Text = "No webcams detected."
            $ProgressBar.Value = 100
            return
        }

        $restartedCount = 0

        foreach ($cam in $webcams) {
            Write-Host "Restarting device: $($cam.Name)"

            try {
                # Disable the device and wait
                Disable-PnpDevice -InstanceId $cam.PNPDeviceID -Confirm:$false -ErrorAction Stop
                Start-Sleep -Seconds 2
                # Enable the device back
                Enable-PnpDevice -InstanceId $cam.PNPDeviceID -Confirm:$false -ErrorAction Stop

                # Update progress
                $restartedCount++
                # Safeguard to prevent division by zero
                if ($totalWebcams -gt 0) {
                    $ProgressBar.Value = (($restartedCount) / $totalWebcams) * 100
                }
            } catch {
                Write-Warning "Failed to restart device: $($cam.Name)`n$($_.Exception.Message)"
                $StatusText.Text = "Error restarting $($cam.Name)"
                $ProgressBar.Value = 100
            }
        }

        # Success message
        [System.Windows.Forms.MessageBox]::Show(
            "Webcam device(s) restarted successfully.",
            "Webcam Restart Complete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        $StatusText.Text = "Webcam(s) restarted successfully."
        $ProgressBar.Value = 100

    } catch {
        # General error handling
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred: $($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        $StatusText.Text = "An error occurred."
        $ProgressBar.Value = 100
    }
})

# Show the window
$window.ShowDialog()
