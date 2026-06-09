<#
.SYNOPSIS
    A Network Diagnostic and Health Check Tool for Windows with WPF-based GUI for performing network-related tasks.

.DESCRIPTION
    This script provides an easy-to-use interface to perform common network repair and diagnostic tasks on a Windows system, including resetting the firewall, repairing network adapters, and clearing Wi-Fi profiles.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.3
    Tested On    : Windows 11 24H2
    Requirements : 
        - Administrator rights to execute network-related commands
        - PowerShell 7+ or newer
        - .NET Framework for WPF GUI
    Features:
        - Reset Firewall
        - Reset Winsock
        - Repair Network Adapter
        - Clear Wi-Fi Profiles
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

# Corrected XAML layout with escaped & as &amp;
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Network Diagnostic &amp; Health Check Tool v0.3'
        Height='460' Width='460'
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
        <TextBlock Text='Network Diagnostic &amp; Health Check Tool v0.3' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='BtnResetFirewall' Content='Reset Windows Firewall to Default'/>
        <Button x:Name='BtnResetWinsock' Content='Reset Winsock Catalog'/>
        <Button x:Name='BtnRepairNICDriver' Content='Repair Network Adapter Driver'/>
        <Button x:Name='BtnClearWiFiProfiles' Content='Clear Wi-Fi Profiles'/>
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

# Access controls
$btnResetFirewall = $window.FindName("BtnResetFirewall")
$btnResetWinsock = $window.FindName("BtnResetWinsock")
$btnRepairNICDriver = $window.FindName("BtnRepairNICDriver")
$btnClearWiFiProfiles = $window.FindName("BtnClearWiFiProfiles")
$progressBar = $window.FindName("ProgressBar")
$statusText = $window.FindName("StatusText")

# Helper function to update status and progress bar
function Update-Status {
    param (
        [string]$Message,
        [int]$ProgressValue = 0
    )
    $statusText.Text = $Message
    $progressBar.Value = $ProgressValue
}

# Button event handlers
$btnResetFirewall.Add_Click({
    Update-Status -Message "Resetting Windows Firewall to Default..."
    Start-Process -FilePath "powershell" -ArgumentList "-Command", "netsh advfirewall reset" -Verb RunAs -Wait
    Update-Status -Message "Firewall reset complete." -ProgressValue 100
})

$btnResetWinsock.Add_Click({
    Update-Status -Message "Resetting Winsock Catalog..."
    Start-Process -FilePath "netsh" -ArgumentList "winsock reset" -Verb RunAs -Wait
    Update-Status -Message "Winsock reset complete. Reboot recommended." -ProgressValue 100
})

$btnRepairNICDriver.Add_Click({
    Update-Status -Message "Disabling Network Adapters..."
    Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Disable-NetAdapter -Confirm:$false
    Start-Sleep -Seconds 3
    Update-Status -Message "Enabling Network Adapters..."
    Get-NetAdapter | Where-Object {$_.Status -eq "Disabled"} | Enable-NetAdapter -Confirm:$false
    Update-Status -Message "Network adapter repair complete." -ProgressValue 100
})

$btnClearWiFiProfiles.Add_Click({
    $confirm = [System.Windows.MessageBox]::Show(
        "This will clear all Wi-Fi profiles including saved passwords. You will need to re-enter Wi-Fi passwords after this action. Continue?",
        "Confirm Wi-Fi Profile Clear",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
        Update-Status -Message "Clearing all Wi-Fi profiles..."
        netsh wlan delete profile name=*
        Update-Status -Message "Wi-Fi profiles cleared." -ProgressValue 100

        [System.Windows.MessageBox]::Show(
            "All Wi-Fi profiles have been cleared. You will need to enter Wi-Fi passwords again to reconnect.",
            "Wi-Fi Profiles Cleared",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
    }
    else {
        Update-Status -Message "Operation cancelled." -ProgressValue 0
    }
})

# Show the window
$window.ShowDialog() | Out-Null
