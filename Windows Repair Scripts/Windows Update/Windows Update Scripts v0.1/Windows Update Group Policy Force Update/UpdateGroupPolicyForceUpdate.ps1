<#
.SYNOPSIS
    Refreshes Group Policy settings through a WPF GUI with an option to restart the computer.

.DESCRIPTION
    This PowerShell script provides a graphical user interface (GUI) to refresh Group Policy settings on the system. The script leverages Windows Presentation Foundation (WPF) to create a user-friendly window with a button to trigger a `gpupdate /force` command. The interface also includes a progress bar to visually indicate the status of the refresh process and displays a message box asking the user if they would like to restart the computer after the update.

    The script checks if it is being run with administrator privileges, relaunches with elevated rights if necessary, and executes the Group Policy update. Once the refresh is complete, the user is prompted with a choice to restart the system after a 2-minute delay.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Administrator rights for executing `gpupdate /force` and triggering system restart.
        - PowerShell 7+ or newer.
        - .NET Framework (for WPF support).
    
    This tool is useful for IT professionals and system administrators who need to refresh Group Policy settings quickly and offer a restart option in a user-friendly GUI.

    The script performs the following functions:
        - Displays a WPF window to initiate a Group Policy update.
        - Updates the progress bar as the `gpupdate /force` command is executed.
        - Prompts the user with an option to restart the system.
        - Handles errors and provides feedback to the user in case of failure.
        
    This tool is designed for Windows 10/11 environments with administrative rights.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load necessary assemblies for WPF
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Define the XAML layout for the UI (only GPUpdate remains)
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Update Group Policy'
        Height='480' Width='460'
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
        <TextBlock Text='Update Group Policy' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='BtnGPUpdate' Content='Refresh Group Policy'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML into a Window object
[xml]$xamlXml = $xaml
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Find UI elements
$BtnGPUpdate = $window.FindName("BtnGPUpdate")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Helper functions
function Update-UI {
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

function Update-Progress {
    param([int]$percent, [string]$message)
    $ProgressBar.Value = $percent
    $StatusText.Text = $message
    Update-UI
}

# Group Policy Refresh
$BtnGPUpdate.Add_Click({
    try {
        Update-Progress -percent 10 -message "Refreshing Group Policy..."
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c gpupdate /force" -Wait
        Update-Progress -percent 100 -message "Group Policy updated."

        $result = [System.Windows.MessageBox]::Show(
            "Group Policy has been updated successfully.`nWould you like to restart your computer in 2 minutes?",
            "Restart Recommended",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )

        if ($result -eq "Yes") {
            shutdown.exe /r /t 120 /c "Restart scheduled to complete Group Policy refresh."
        }

        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to refresh Group Policy.`n$($_.Exception.Message)", "Error",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# Show the window
$window.ShowDialog()
