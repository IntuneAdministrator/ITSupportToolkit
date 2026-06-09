<#
.SYNOPSIS
    Fixes DNS settings on the system using a graphical interface, with a progress bar and user prompts.

.DESCRIPTION
    This PowerShell script provides a GUI utility for resetting DNS settings on a system. The script enables the user to reset the DNS configuration to Google DNS (8.8.8.8 and 8.8.4.4) via a simple WPF interface. 
    The user can click the "Fix DNS Settings" button to initiate the reset process, during which a progress bar will update in real time to show the progress of the reset on each network adapter.
    After the process completes, the user is prompted to restart the computer to apply the changes. The script requires administrator privileges to modify network settings.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Admin rights to modify DNS settings.
        - .NET Framework (for WPF and WinForms)
        - PowerShell 7+ or newer

    This tool is especially useful for IT professionals or users troubleshooting network issues related to DNS settings.
    
    The script performs the following functions:
        - Resets DNS settings to Google DNS servers (8.8.8.8, 8.8.4.4) on all enabled network adapters.
        - Displays a progress bar to show the progress of the DNS reset.
        - Prompts the user to restart the computer after the DNS settings have been updated.
        
    Designed for Windows 11 systems with administrative rights.
#>

# Requires admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("This script requires Administrator privileges. Please run it as Administrator.","Elevation Required",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error)
    exit
}

# Load required assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define styled XAML
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='DNS Fix Utility'
        Height='300' Width='460'
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
        <TextBlock Text='DNS Repair Tool' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='FixButton' Content='Fix DNS Settings'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load the XAML UI
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Reference UI elements
$fixButton   = $window.FindName("FixButton")
$progressBar = $window.FindName("ProgressBar")
$statusText  = $window.FindName("StatusText")

function Set-UIState {
    param([bool]$running)
    $fixButton.IsEnabled = -not $running
    if (-not $running) {
        $progressBar.Value = 0
    }
}

function Fix-DNS {
    Set-UIState -running $true
    $statusText.Text = "Starting DNS reset..."
    [System.Windows.Forms.Application]::DoEvents()

    $dnsServers = @("8.8.8.8", "8.8.4.4")

    try {
        $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        $total = $adapters.Count

        if ($total -eq 0) {
            $statusText.Text = "No enabled adapters found."
            Set-UIState -running $false
            return
        }

        $count = 0

        foreach ($adapter in $adapters) {
            $desc = $adapter.Description

            $statusText.Text = "Clearing DNS for: $desc"
            [System.Windows.Forms.Application]::DoEvents()
            $adapter | Invoke-CimMethod -MethodName SetDNSServerSearchOrder -Arguments @{ DNSServerSearchOrder = $null }
            Start-Sleep -Milliseconds 300

            $statusText.Text = "Setting Google DNS for: $desc"
            [System.Windows.Forms.Application]::DoEvents()
            $adapter | Invoke-CimMethod -MethodName SetDNSServerSearchOrder -Arguments @{ DNSServerSearchOrder = $dnsServers }
            Start-Sleep -Milliseconds 300

            $count++
            $progressBar.Value = [math]::Round(($count / $total) * 100)
            $statusText.Text = "Updated $count of $total adapters..."
            [System.Windows.Forms.Application]::DoEvents()
        }

        $progressBar.Value = 100
        $statusText.Text = "DNS settings updated successfully."
    } catch {
        $statusText.Text = "Error: $($_.Exception.Message)"
    }

    Set-UIState -running $false

    $result = [System.Windows.MessageBox]::Show(
        "Network settings have been reset.`nDo you want to restart your computer now?",
        "Restart Required",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )

    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        shutdown /r /t 30 /c "Restart initiated by DNS repair script."
    }
}

# Bind button event
$fixButton.Add_Click({ Fix-DNS })

# Run the UI
$window.ShowDialog() | Out-Null
