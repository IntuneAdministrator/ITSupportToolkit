<#
.SYNOPSIS
    A WPF-based GUI tool to perform network diagnostics and health checks on a Windows system.

.DESCRIPTION
    This PowerShell script provides a graphical interface for network diagnostics, allowing users to reset TCP/IP settings, flush DNS cache, renew IP address, restart network adapters, perform a ping test, and view IP configuration. 
    The tool is designed to assist IT professionals and advanced users in troubleshooting network connectivity issues and optimizing network configurations.

    The script uses Windows Presentation Foundation (WPF) to create a simple and user-friendly GUI, featuring buttons for each network operation and a progress bar for real-time feedback. It also ensures that the script is run with administrator privileges for required network-related commands.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Administrator rights for network configuration changes (e.g., resetting TCP/IP, renewing IP).
        - PowerShell 7+ or newer to run the script with WPF support.
        - .NET Framework for GUI rendering.

    Features:
        - Reset TCP/IP stack.
        - Flush DNS cache.
        - Release and renew IP address.
        - Restart network adapters.
        - Perform a ping test (to 8.8.8.8).
        - View detailed IP configuration.
        - Simple WPF interface with real-time status updates.
        
    This tool is ideal for resolving common network issues on Windows-based systems.

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

# Define the XAML layout for the UI
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Network Diagnostic &amp; Health Check Tool v0.2'
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
            <Setter Property='Height' Value='20'/>
            <Setter Property='Margin' Value='0,0,0,10'/>
        </Style>
    </Window.Resources>
    <StackPanel Margin='20' HorizontalAlignment='Center'>
        <TextBlock Text='Network Diagnostic &amp; Health Check Tool v0.2' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='BtnResetTCPIP' Content='Reset TCP/IP Stack'/>
        <Button x:Name='BtnFlushDNS' Content='Flush DNS Cache'/>
        <Button x:Name='BtnRenewIP' Content='Release and Renew IP'/>
        <Button x:Name='BtnRestartNIC' Content='Restart Network Adapter'/>
        <Button x:Name='BtnPingTest' Content='Ping Test (8.8.8.8)'/>
        <Button x:Name='BtnShowIPConfig' Content='Show IP Configuration'/>
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
$BtnResetTCPIP = $window.FindName("BtnResetTCPIP")
$BtnFlushDNS = $window.FindName("BtnFlushDNS")
$BtnRenewIP = $window.FindName("BtnRenewIP")
$BtnRestartNIC = $window.FindName("BtnRestartNIC")
$BtnPingTest = $window.FindName("BtnPingTest")
$BtnShowIPConfig = $window.FindName("BtnShowIPConfig")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Helper function to update UI safely
function Update-UI {
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

# Function to update progress bar and status text
function Update-Progress {
    param(
        [int]$percent,
        [string]$message
    )
    $ProgressBar.Value = $percent
    $StatusText.Text = $message
    Update-UI
}

# Check admin rights function
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Button event handlers

# Reset TCP/IP Stack
$BtnResetTCPIP.Add_Click({
    if (-not (Test-Admin)) {
        [System.Windows.MessageBox]::Show("Please run as Administrator to reset TCP/IP stack.", "Admin Rights Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    try {
        Update-Progress -percent 0 -message "Resetting TCP/IP stack..."
        netsh int ip reset | Out-Null
        Update-Progress -percent 100 -message "TCP/IP stack reset successfully."
        Start-Sleep -Seconds 2
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to reset TCP/IP stack.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# Flush DNS Cache
$BtnFlushDNS.Add_Click({
    if (-not (Test-Admin)) {
        [System.Windows.MessageBox]::Show("Please run as Administrator to flush DNS cache.", "Admin Rights Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    try {
        Update-Progress -percent 0 -message "Flushing DNS cache..."
        ipconfig /flushdns | Out-Null
        Update-Progress -percent 100 -message "DNS cache flushed successfully."
        Start-Sleep -Seconds 2
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to flush DNS cache.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# Release and Renew IP
$BtnRenewIP.Add_Click({
    if (-not (Test-Admin)) {
        [System.Windows.MessageBox]::Show("Please run as Administrator to release and renew IP.", "Admin Rights Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    try {
        Update-Progress -percent 0 -message "Releasing IP address..."
        ipconfig /release | Out-Null
        Update-Progress -percent 50 -message "Renewing IP address..."
        ipconfig /renew | Out-Null
        Update-Progress -percent 100 -message "IP address renewed successfully."
        Start-Sleep -Seconds 2
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to renew IP address.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# Restart Network Adapter
$BtnRestartNIC.Add_Click({
    if (-not (Test-Admin)) {
        [System.Windows.MessageBox]::Show("Please run as Administrator to restart network adapter.", "Admin Rights Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }
    try {
        Update-Progress -percent 0 -message "Restarting network adapter..."
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        foreach ($adapter in $adapters) {
            Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2
            Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2
        }
        Update-Progress -percent 100 -message "Network adapter(s) restarted successfully."
        Start-Sleep -Seconds 2
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to restart network adapter.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# Ping Test (8.8.8.8)
$BtnPingTest.Add_Click({
    try {
        Update-Progress -percent 0 -message "Performing ping test..."
        $pingResult = Test-Connection -ComputerName 8.8.8.8 -Count 4 -ErrorAction Stop
        $avgTime = ($pingResult | Measure-Object ResponseTime -Average).Average
        $msg = "Ping successful.`nAverage Response Time: {0:N2} ms" -f $avgTime
        [System.Windows.MessageBox]::Show($msg, "Ping Test Result", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Ping test failed.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# Show IP Configuration
$BtnShowIPConfig.Add_Click({
    try {
        $ipconfig = ipconfig /all | Out-String
        $window.Dispatcher.Invoke([action]{
            $msgBox = New-Object System.Windows.Window
            $msgBox.Title = "IP Configuration"
            $msgBox.Width = 480
            $msgBox.Height = 400
            $msgBox.WindowStartupLocation = 'CenterOwner'
            $scrollViewer = New-Object System.Windows.Controls.ScrollViewer
            $textBlock = New-Object System.Windows.Controls.TextBlock
            $textBlock.Text = $ipconfig
            $textBlock.TextWrapping = 'Wrap'
            $textBlock.Margin = '10'
            $scrollViewer.Content = $textBlock
            $msgBox.Content = $scrollViewer
            $msgBox.ShowDialog() | Out-Null
        })
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to get IP configuration.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }
})

# Show the window
$window.ShowDialog() | Out-Null
