<#
.SYNOPSIS
    A script to configure dual monitor setups to "Extend" mode on a Windows system. It provides a GUI for users to initiate the setup and display progress during the process.

.DESCRIPTION
    This PowerShell script provides a simple graphical user interface (GUI) for configuring dual monitor displays in "Extend" mode. The script:
    - Detects connected monitors.
    - Checks if at least two monitors are connected.
    - Uses the `DisplaySwitch.exe` tool to extend the display across the monitors.
    - Provides progress feedback and error messages if something goes wrong.

    Requirements:
    - Windows 10 or later.
    - At least two monitors connected to the system.
    - Admin rights might be required for running the `DisplaySwitch.exe` command.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 10/11
    Dependencies : .NET Framework, DisplaySwitch.exe (native Windows utility)

    Changes in Version 1.0:
    - Initial release to set up dual monitors in Extend mode.
    - Implements progress feedback during setup.
    - Handles errors if monitors are not detected or other issues arise during setup.
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
        Title='Dual Monitor Setup'
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
        <TextBlock Text='Dual Monitor Setup' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='ExtendDisplayButton' Content='Extend Display'/>
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
$ExtendDisplayButton = $window.FindName("ExtendDisplayButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Define the logic for configuring dual monitor setup
$ExtendDisplayButton.Add_Click({
    try {
        # Function to retrieve connected monitor details via WMI
        function Get-ConnectedMonitors {
            Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams | 
            Select-Object InstanceName, MaxHorizontalImageSize, MaxVerticalImageSize
        }

        # Get the list of connected monitors
        $monitors = Get-ConnectedMonitors

        # Validate that at least two monitors are connected
        if ($monitors.Count -lt 2) {
            # Inform the user if less than two monitors are connected
            $StatusText.Text = "Less than two monitors detected. Please connect a second monitor to proceed."
            $ProgressBar.Value = 100
            return
        }

        # Inform user that the system is about to configure the dual monitor setup
        $StatusText.Text = "Configuring dual monitor setup to Extend mode..."
        $ProgressBar.Value = 50

        # Extend the desktop across all connected monitors
        Start-Process -FilePath "C:\Windows\System32\DisplaySwitch.exe" -ArgumentList "/extend" -Wait

        # Update status after the process
        $StatusText.Text = "Dual monitor setup configured to Extend mode."
        $ProgressBar.Value = 100

        # Inform the user of successful configuration
        [System.Windows.Forms.MessageBox]::Show(
            "Dual monitor setup has been configured to Extend mode. Please adjust resolution and primary monitor in Display Settings as needed.",
            "Dual Monitor Setup",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        # Show error message if something goes wrong
        $StatusText.Text = "An error occurred during dual monitor setup."
        $ProgressBar.Value = 100
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred during dual monitor setup:`n$_",
            "Dual Monitor Setup Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# Show the window
$window.ShowDialog()
