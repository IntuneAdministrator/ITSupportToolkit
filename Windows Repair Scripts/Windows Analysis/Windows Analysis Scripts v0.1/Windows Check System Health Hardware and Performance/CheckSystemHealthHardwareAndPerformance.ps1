<#
.SYNOPSIS
    Performs a system health check with a styled WPF GUI.

.DESCRIPTION
    This PowerShell script provides a graphical user interface (GUI) for performing a system health check on the local machine. The script gathers information on CPU usage, memory usage, and disk space usage, and displays the results in a styled message box. It is designed using Windows Presentation Foundation (WPF) to match Allester Padovani's modern UI standards.

    The health check is initiated by clicking the "Start System Health Check" button. A progress bar is displayed during the check, and the user is informed once the check is complete. The results of the check are displayed in a message box, including detailed statistics for CPU, RAM, and disk usage.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements : 
        - Admin rights to collect system health data
        - .NET Framework (for WPF and WinForms)
        - PowerShell 7+ or newer

    This script is designed to help IT administrators or users quickly assess the system's health by checking the resource usage. It is compatible with modern Windows versions and works seamlessly with PowerShell 7 or higher. The clean WPF interface ensures a smooth and intuitive user experience.

    The script makes use of `Get-WmiObject` to collect system data and provides progress feedback with a progress bar while performing the health check.

    The following data is gathered:
        - CPU Usage
        - Memory Usage
        - Disk Space Usage (for local drives)
    
    After completion, the script displays the results in a message box and informs the user of the current status of the system.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# XAML UI
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="System Health Check"
        Height="460" Width="460"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Background="#f4f4f4"
        FontFamily="Segoe UI"
        FontSize="12"
        SizeToContent='WidthAndHeight'>
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#f4f4f4"/>
            <Setter Property="Foreground" Value="Black"/>
            <Setter Property="BorderBrush" Value="#cccccc"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Width" Value="400"/>
            <Setter Property="Height" Value="30"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>
    </Window.Resources>
    <StackPanel Margin="20" HorizontalAlignment="Center">
        <TextBlock Text="System Health Scanner" FontSize="16" FontWeight="Bold" Margin="0,0,0,20" HorizontalAlignment="Center"/>
        <Button x:Name="StartButton" Content="Start System Health Check"/>
        <ProgressBar x:Name="ProgressBar" Height="25" Width="400" Minimum="0" Maximum="100" Margin="0,5,0,5"/>
        <TextBlock x:Name="StatusLabel" Text="Press the button to start check." FontSize="12" Foreground="Black"/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Parse and load UI
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Access controls
$StartButton = $window.FindName("StartButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusLabel = $window.FindName("StatusLabel")

# Function: Show MessageBox
function Show-Message {
    param ($msg, $title = "System Health Report")
    [System.Windows.Forms.MessageBox]::Show($msg, $title, 'OK', 'Information') | Out-Null
}

# Function: Update UI
function Update-UI {
    param([string]$Message, [int]$Percent = $null)
    $window.Dispatcher.Invoke([action]{
        $StatusLabel.Text = $Message
        if ($Percent -ne $null) {
            $ProgressBar.Value = [Math]::Min($Percent, 100)
        }
        [System.Windows.Forms.Application]::DoEvents()
    })
}

# Button handler
$StartButton.Add_Click({
    $StartButton.IsEnabled = $false
    Update-UI "Starting system health check..." 0

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    $ps.AddScript({
        $out = @()
        $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $out += "System Health Check at $now"

        # CPU
        $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1 -ExpandProperty LoadPercentage
        $out += "CPU Usage: $cpu%"

        # RAM
        $os = Get-WmiObject Win32_OperatingSystem
        $ramUsed = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100, 2)
        $out += "Memory Usage: $ramUsed%"

        # Disk
        $disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"
        foreach ($d in $disks) {
            if ($d.Size -and $d.FreeSpace) {
                $used = [math]::Round(($d.Size - $d.FreeSpace) / $d.Size * 100, 2)
                $out += "Disk $($d.DeviceID): $used% used"
            }
        }

        return ($out -join "`r`n")
    }) | Out-Null

    $async = $ps.BeginInvoke()

    while (-not $async.IsCompleted) {
        $p = [math]::Min($ProgressBar.Value + 1, 99)
        Update-UI "Checking system components..." $p
        Start-Sleep -Milliseconds 100
    }

    $result = $ps.EndInvoke($async)
    $ps.Dispose()
    $runspace.Close()
    $runspace.Dispose()

    Update-UI "Health check complete." 100
    Show-Message -msg $result
    $StartButton.IsEnabled = $true
    Update-UI "Ready." 0
})

# Show window
[void]$window.ShowDialog()
