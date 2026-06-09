<#
.SYNOPSIS
    WPF GUI for Audio Device Reinstallation on Windows 11.

.DESCRIPTION
    This script provides a graphical user interface (GUI) to uninstall and automatically reinstall audio devices on a Windows 11 machine.
    The GUI includes a button to trigger the uninstallation of all active audio devices, a progress bar to track the uninstallation process,
    and status messages to inform the user of the current operation.
    After uninstalling, the script forces a device rescan to trigger Windows to reinstall the necessary drivers automatically.
    It also handles errors and displays success or failure messages in a user-friendly manner.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2  
    Requirements : Admin rights, Outlook installed, .NET Framework (for WPF and WinForms)
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
        Title='Audio Device Reinstallation'
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
        <TextBlock Text='Audio Device Reinstallation' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='UninstallAudioButton' Content='Uninstall Audio Devices'/>
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
$UninstallAudioButton = $window.FindName("UninstallAudioButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Define the logic for uninstalling audio devices
$UninstallAudioButton.Add_Click({
    try {
        # Retrieve all working audio (Media class) devices
        $audioDevices = Get-PnpDevice -Class Media -Status OK

        # Confirm uninstallation with the user using MessageBox
        $userConfirm = [System.Windows.Forms.MessageBox]::Show(
            "This will uninstall all active audio devices. Windows will attempt to reinstall them automatically after a scan." + [Environment]::NewLine + [Environment]::NewLine + "Do you want to continue?",
            "Confirm Audio Device Reinstallation",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($userConfirm -ne [System.Windows.Forms.DialogResult]::Yes) {
            [System.Windows.Forms.MessageBox]::Show("Operation canceled by user.", "Operation Cancelled", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            exit 0
        }

        # Loop through each audio device and uninstall it
        $failedUninstalls = @()
        $totalDevices = $audioDevices.Count
        $uninstalledCount = 0

        foreach ($device in $audioDevices) {
            # Update progress bar and status text
            $StatusText.Text = "Uninstalling device: $($device.Name)"
            $ProgressBar.Value = (($uninstalledCount + 1) / $totalDevices) * 100

            pnputil /remove-device "$($device.InstanceId)" | Out-Null
            Start-Sleep -Seconds 2

            $uninstalledCount++
        }

        # Trigger device rescan to force driver reinstallation
        Start-Process -FilePath "pnputil.exe" -ArgumentList "/scan-devices" -Wait

        # Notify user of successful uninstallation and reinstallation process
        [System.Windows.Forms.MessageBox]::Show(
            "Audio devices uninstalled successfully. Windows will reinstall the drivers automatically." + [Environment]::NewLine + "A system reboot may be required.",
            "Audio Devices Reinstalled",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        # Capture and display any errors encountered during execution
        $StatusText.Text = "An error occurred while uninstalling audio devices."
        $ProgressBar.Value = 100
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred while uninstalling audio devices:`n$_",
            "Audio Device Uninstallation Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# Handle window closing to just close without doing anything else
$window.Add_Closing({
    # Do nothing here, just let the window close normally
})

# Show the window
$window.ShowDialog()
