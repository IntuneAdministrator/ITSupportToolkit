<#
.SYNOPSIS
    Performs an internet connectivity test with a styled WPF GUI.

.DESCRIPTION
    This PowerShell script provides a graphical user interface (GUI) for testing internet connectivity. 
    It uses the `Test-Connection` cmdlet to ping a target host (by default, google.com), displaying the results in a styled message box. 
    The user is provided with progress feedback via a progress bar, and the test results are shown in a message box detailing packet loss and average latency.

    The script ensures that it is run as an administrator, and provides clear feedback to the user on the test status. 
    A warning is shown if the average latency exceeds 40ms, and error handling is built in to manage connection failures.

.NOTES
    Author       : Allester Padovani
    Date         : July 18, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements : 
        - Admin rights
        - Outlook installed
        - .NET Framework (for WPF and WinForms)
        - PowerShell 7+ or higher
    This script is intended to be a simple and user-friendly tool for checking internet connectivity, suitable for IT administrators or general users.

    Known Issues:
        - The target host is currently set to `google.com`, but this can be customized for testing other hosts.
        - It assumes the availability of `Test-Connection`, which is supported on most modern versions of Windows.

    Change History:
        - Version 1.0: Initial release.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Ensure the required assemblies are loaded for WPF and Windows Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# XAML UI definition
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Internet Connectivity Test'
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
        <TextBlock Text='Internet Connectivity Test' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='StartTestButton' Content='Start Test'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Click "Start Test" to begin.' FontSize='12' Foreground='black' Margin='0,0,0,10'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Convert string to XML and load XAML
[xml]$xamlXml = $xaml
$reader = New-Object System.Xml.XmlNodeReader($xamlXml)
$Window = [System.Windows.Markup.XamlReader]::Load($reader)

# Find UI elements after window is loaded
$StartTestButton = $Window.FindName("StartTestButton")
$ProgressBar = $Window.FindName("ProgressBar")
$StatusText = $Window.FindName("StatusText")

# Helper function to update UI responsively
function Update-UI {
    param($percent, $text)
    $ProgressBar.Value = $percent
    $StatusText.Text = $text
    [System.Windows.Forms.Application]::DoEvents()
}

# Ping test function
function Run-PingTest {
    try {
        $targetHost = "google.com"
        $StartTestButton.IsEnabled = $false
        
        # Simulate start progress
        for ($i = 0; $i -le 20; $i += 5) {
            Update-UI $i "Initializing... $i%"
            Start-Sleep -Milliseconds 100
        }

        Update-UI 30 "Pinging $targetHost..."
        $pings = Test-Connection -ComputerName $targetHost -Count 10 -ErrorAction Stop

        Update-UI 60 "Analyzing results..."
        $grouped = $pings | Group-Object -Property Address
        $isSlow = $false
        $message = "Internet Connectivity Test Results:`n`n"

        foreach ($group in $grouped) {
            $ip = $group.Name
            $responses = $group.Group
            $sent = $responses.Count
            $received = ($responses | Where-Object { $_.StatusCode -eq 0 }).Count
            $lost = $sent - $received
            $lossPercent = [math]::Round(($lost / $sent) * 100, 2)
            $avgRTT = [math]::Round(($responses | Measure-Object -Property ResponseTime -Average).Average, 2)

            if ($avgRTT -gt 40) {
                $isSlow = $true
            }

            $message += @"
Target Host       : $targetHost
Resolved IP       : $ip
Packets Sent      : $sent
Packets Received  : $received
Packets Lost      : $lost
Packet Loss       : $lossPercent%
Average Latency   : $avgRTT ms
"@
            $message += "`n-------------------------------------------`n"
        }

        Update-UI 100 "Test complete. You can run again if needed."
        Start-Sleep -Seconds 1

        # Show message box with results or warning
        if ($isSlow) {
            [System.Windows.Forms.MessageBox]::Show(
                "Internet is super slow (latency > 40ms).`nPlease reach out to your provider as soon as possible.",
                "Performance Warning",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                $message,
                "Internet Test Results",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        if ($Window -and $Window.IsVisible) { $Window.Dispatcher.Invoke({ $Window.Close() }, 'Render') }
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to reach $targetHost.`nError: $($_.Exception.Message)",
            "Connection Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $StartTestButton.IsEnabled = $true
    }
}

# Attach click event to Start button
$StartTestButton.Add_Click({
    Run-PingTest
})

# Show the window (blocking call)
[void]$Window.ShowDialog()
