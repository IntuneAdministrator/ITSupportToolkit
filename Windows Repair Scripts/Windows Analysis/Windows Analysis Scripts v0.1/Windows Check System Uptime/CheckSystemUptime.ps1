<#
.SYNOPSIS
    Displays system uptime since last boot using a WPF GUI.

.DESCRIPTION
    This PowerShell script provides a graphical user interface (GUI) for displaying the system uptime since the last boot. It retrieves the system boot time by pulling Event ID 6005 (System boot event) from the Event Log and calculates the uptime. The results are displayed in a styled Windows Forms message box.

    The user interacts with the script via a WPF interface with a "Show System Uptime" button, which, when clicked, retrieves the system's uptime and displays the result in a message box. A progress bar is shown during the calculation to provide feedback on the operation.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements : 
        - Admin rights (to access Event Logs)
        - .NET Framework (for WPF and WinForms)
        - PowerShell 7+ or newer

    The script fetches the system's last boot time (Event ID 6005) from the "System" event log, calculates the uptime duration, and formats it into days, hours, minutes, and seconds. The progress bar updates as the uptime is calculated, and any errors encountered are displayed in a message box.

    This script is ideal for IT administrators or users who need to quickly determine the system's uptime in a visually appealing way. It is compatible with modern Windows versions and PowerShell 7+.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# WPF UI
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="System Uptime Viewer"
        Height="320" Width="420"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Background="#f4f4f4"
        FontFamily="Segoe UI" FontSize="12"
        SizeToContent='WidthAndHeight'>
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#f4f4f4"/>
            <Setter Property="Foreground" Value="Black"/>
            <Setter Property="BorderBrush" Value="#cccccc"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Width" Value="360"/>
            <Setter Property="Height" Value="30"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>
    </Window.Resources>
    <StackPanel Margin="20" HorizontalAlignment="Center">
        <TextBlock Text="System Uptime Status" FontSize="16" FontWeight="Bold" Margin="0,0,0,20" HorizontalAlignment="Center"/>
        <Button x:Name="ShowUptimeButton" Content="Show System Uptime"/>
        <ProgressBar x:Name="ProgressBar" Height="25" Width="360" Minimum="0" Maximum="100" Margin="0,5,0,5"/>
        <TextBlock x:Name="StatusLabel" Text="Press the button to get system uptime." FontSize="12" Foreground="Black"/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load UI
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Access elements
$StatusLabel = $window.FindName("StatusLabel")
$ShowUptimeButton = $window.FindName("ShowUptimeButton")
$ProgressBar = $window.FindName("ProgressBar")

# Update UI helper
function Update-UI {
    param(
        [string]$Message,
        [int]$PercentComplete = $null
    )
    $window.Dispatcher.Invoke([action]{
        $StatusLabel.Text = $Message
        if ($PercentComplete -ne $null) {
            $ProgressBar.Value = [math]::Min([math]::Max($PercentComplete, 0), 100)
        }
        [System.Windows.Forms.Application]::DoEvents()
    })
}

# Button action
$ShowUptimeButton.Add_Click({
    try {
        # Animate progress
        for ($i = 0; $i -le 100; $i += 10) {
            Update-UI "Calculating uptime... $i%" $i
            Start-Sleep -Milliseconds 80
        }

        # Get last boot event (Event ID 6005)
        $bootEvent = Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 6005 } -MaxEvents 1
        if (-not $bootEvent) {
            throw "Boot event (ID 6005) not found."
        }

        $bootTime = $bootEvent.TimeCreated
        $now = Get-Date
        $uptime = $now - $bootTime
        $formatted = "{0} days, {1} hours, {2} minutes, {3} seconds" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds

        $msg = @"
System Uptime Based on Event Logs:

Boot Time       : $bootTime
Current Time    : $now
Uptime Duration : $formatted
"@

        [System.Windows.Forms.MessageBox]::Show($msg, "Uptime Status", 'OK', 'Information')
        Update-UI "Uptime displayed successfully." 100
    }
    catch {
        Update-UI "Error occurred: $_" 0
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Error", 'OK', 'Error')
    }
})

# Launch window
[void]$window.ShowDialog()
