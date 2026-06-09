<#
.SYNOPSIS
    A tool for uninstalling all detected webcam devices on a Windows machine. The script utilizes WMI (Windows Management Instrumentation) to find and uninstall webcams, and provides a progress bar along with detailed feedback in the GUI.

.DESCRIPTION
    This script provides a graphical user interface (GUI) that allows users to uninstall all detected webcam devices from their Windows system. The tool performs the following tasks:
    - Queries the system for all active webcam devices (excluding printers and multifunction devices).
    - Displays a confirmation dialog asking if the user wants to continue with the uninstallation.
    - Uninstalls each detected webcam device while showing a progress bar.
    - If any devices fail to uninstall, the user is notified with a list of failed devices and instructions for manual removal.
    - Displays status updates during the operation in the form of a status message.

    The tool also includes functionality to handle errors gracefully and inform the user if something goes wrong.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2
    Requirements : Admin rights, .NET Framework (for WPF), and appropriate permissions to uninstall devices via WMI.

    Changes in Version 1.0:
    - Initial release of the tool.
    - Added the ability to uninstall all detected webcam devices.
    - Implemented GUI with a progress bar for uninstalling webcam devices.
    - Error handling for failed uninstalls and manual intervention notification.

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

# Define the XAML layout for the new UI
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Webcam Uninstall'
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
        <TextBlock Text='Webcam Uninstall' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='UninstallWebcamsButton' Content='Uninstall Webcams'/>
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
$UninstallWebcamsButton = $window.FindName("UninstallWebcamsButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Define the logic to uninstall webcams
$UninstallWebcamsButton.Add_Click({
    # Confirm user wants to continue
    $userChoice = [System.Windows.Forms.MessageBox]::Show(
        "This will uninstall all detected webcam devices. Windows will reinstall drivers automatically." + [Environment]::NewLine + "Do you want to continue?",
        "Confirm Webcam Uninstall",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($userChoice -ne [System.Windows.Forms.DialogResult]::Yes) {
        $StatusText.Text = "Operation cancelled by user."
        $ProgressBar.Value = 100
        return
    }

    try {
        # Query webcams, excluding printers and MFPs
        $webcams = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_PnPEntity | Where-Object {
            ($_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image') -and
            ($_.Name -notmatch 'Printer|OfficeJet|Fax|Scan|Copy')
        }

        if (-not $webcams) {
            $StatusText.Text = "No webcam devices detected."
            $ProgressBar.Value = 100
            return
        }

        $uninstallFailures = @()
        $totalWebcams = $webcams.Count
        $uninstalledCount = 0
        $StatusText.Text = "Uninstalling webcam devices..."

        # Reset progress bar
        $ProgressBar.Value = 0

        foreach ($cam in $webcams) {
            try {
                # Uninstall device
                Write-Output "Uninstalling device: $($cam.Name)"
                Remove-PnpDevice -InstanceId $cam.DeviceID -Confirm:$false -ErrorAction Stop
                Start-Sleep -Seconds 3

                # Update progress bar
                $uninstalledCount++
                $ProgressBar.Value = (($uninstalledCount) / $totalWebcams) * 100
            } catch {
                Write-Warning "Failed to uninstall device: $($cam.Name)"
                $uninstallFailures += $cam.Name
            }
        }

        # Handle results
        if ($uninstallFailures.Count -gt 0) {
            $failedList = ($uninstallFailures -join "`n")
            $StatusText.Text = "Some devices could not be uninstalled. Please uninstall manually."
            [System.Windows.Forms.MessageBox]::Show(
                "Some devices could not be uninstalled:`n`n$failedList`n`nPlease uninstall them manually or contact support.",
                "Manual Intervention Required",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        } else {
            $StatusText.Text = "Webcam device(s) uninstalled successfully."
        }

        # Final status
        $ProgressBar.Value = 100

    } catch {
        # Handle any unexpected errors
        $StatusText.Text = "An error occurred: $($_.Exception.Message)"
        $ProgressBar.Value = 100
    }
})

# Show the window
$window.ShowDialog()
