<#
.SYNOPSIS
    A tool for checking and diagnosing webcam devices on a Windows machine. The tool uses WMI (Windows Management Instrumentation) to query all imaging devices (webcams) and provides a detailed status of each webcam, including its name, status, and device ID.

.DESCRIPTION
    This script provides a graphical user interface (GUI) built using WPF (Windows Presentation Foundation) to interact with the system's webcam devices. It queries the system for all active webcams, checks their status, and displays detailed information for each device. If no webcam devices are found, it notifies the user accordingly. 

    The script performs the following tasks:
    - Queries the system for webcams using WMI.
    - Displays the status of each webcam (e.g., if it's working or disabled).
    - Excludes printers and multifunction devices from the webcam search.
    - Provides a progress bar for visual feedback while checking the webcams.
    - Displays a status message for each webcam in a message box.
    - Notifies the user if no webcams are found or if an error occurs.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2
    Requirements : Admin rights, .NET Framework (for WPF), and appropriate permissions to query WMI.

    Changes in Version 1.0:
    - Initial release of the tool.
    - Added functionality to query and check the status of all webcam devices.
    - Implemented GUI-based controls using WPF to display webcam statuses.
    - Integrated progress bar for visual feedback during webcam checks.
    
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

# Define the XAML layout for the new UI (escaping the "&" character as "&amp;")
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Webcam Status &amp; Diagnostics'
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
        <TextBlock Text='Webcam Status &amp; Diagnostics' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='CheckWebcamsButton' Content='Check Webcams'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get UI elements
$CheckWebcamsButton = $window.FindName("CheckWebcamsButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Define logic to check webcam status and display progress
$CheckWebcamsButton.Add_Click({
    try {
        # Query WMI for imaging devices (webcams)
        $webcams = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_PnPEntity |
            Where-Object { 
                ($_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image') -and
                ($_.Name -notmatch 'Printer|OfficeJet|Fax|Scan|Copy') # exclude printers and multifunction devices
            }

        if ($webcams.Count -eq 0) {
            # No webcams found
            $StatusText.Text = "No webcam devices were found."
            $ProgressBar.Value = 100
        } else {
            # Process webcam devices and show details
            $totalWebcams = $webcams.Count
            $updatedCount = 0
            $StatusText.Text = "Checking webcam devices..."

            # Reset progress bar
            $ProgressBar.Value = 0

            # Loop through each webcam and display its status
            foreach ($cam in $webcams) {
                $StatusText.Text = "Processing $($cam.Name)..."

                # Only update the progress bar if totalWebcams > 0
                if ($totalWebcams -gt 0) {
                    # Update progress bar
                    $updatedCount++
                    $ProgressBar.Value = (($updatedCount) / $totalWebcams) * 100
                }

                # Prepare status message
                $statusReport = "Device Name: $($cam.Name)`n"
                $statusReport += "Status: $($cam.Status)`n"
                $statusReport += "Device ID: $($cam.DeviceID)`n"
                $statusReport += "----------------------------------------`n"

                # Show webcam info in message box
                [System.Windows.Forms.MessageBox]::Show(
                    $statusReport,
                    "Webcam Device Found",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }

            $StatusText.Text = "All webcam devices processed successfully."
            $ProgressBar.Value = 100
        }
    } catch {
        # Handle errors and show error message
        $StatusText.Text = "An error occurred: $_"
        $ProgressBar.Value = 100
    }
})

# Show the window
$window.ShowDialog()
