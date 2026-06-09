<#
.SYNOPSIS
    WPF GUI for restarting audio services on Windows 11.

.DESCRIPTION
    This script provides a graphical user interface (GUI) to restart the audio-related services (`AudioEndpointBuilder` and `Audiosrv`) on a Windows 11 system.
    The GUI includes a button to trigger the restart of these services, a progress bar to track the operation, and status messages to inform the user
    about the progress or any errors that occur during the process.
    If the services are successfully restarted, a message is shown to the user. If any service fails to restart, the script displays the names
    of the failed services.

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
        Title='Audio Service Restart'
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
        <TextBlock Text='Restart Audio Services' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='RestartButton' Content='Restart Audio Services'/>
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
$RestartButton = $window.FindName("RestartButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Define the logic for restarting audio services
$RestartButton.Add_Click({
    try {
        # Define audio-related services to restart
        $services = @("AudioEndpointBuilder", "Audiosrv")
        
        # Initialize failure list
        $failedServices = @()

        # Loop through each service and restart it
        foreach ($service in $services) {
            try {
                # Restart service
                Restart-Service -Name $service -Force -ErrorAction Stop
                Start-Sleep -Seconds 2  # Brief pause to allow service to restart properly
            } catch {
                # If service restart fails, add to failed list
                $failedServices += $service
            }
        }

        # Update progress bar and status text after operation
        $ProgressBar.Value = 100
        if ($failedServices.Count -eq 0) {
            $StatusText.Text = "Audio services restarted successfully."
            [System.Windows.Forms.MessageBox]::Show(
                "Audio services have been restarted successfully.",
                "Success",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        } else {
            $failedList = $failedServices -join "`n"
            $StatusText.Text = "Failed to restart the following services: $failedList"
            [System.Windows.Forms.MessageBox]::Show(
                "The following audio services could not be restarted:`n`n$failedList",
                "Service Restart Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
    catch {
        # General error handling
        $ProgressBar.Value = 100
        $StatusText.Text = "An error occurred during service restart."
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred while restarting the audio services:`n$_",
            "Service Restart Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# Show the window
$window.ShowDialog()
