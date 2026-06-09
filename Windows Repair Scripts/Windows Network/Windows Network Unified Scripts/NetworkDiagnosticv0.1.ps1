<#
.SYNOPSIS
    A network diagnostic tool that provides several network-related features such as setting DNS, showing network info, restarting network adapters, adjusting speed/duplex settings, and resetting the network configuration.

.DESCRIPTION
    This script provides a GUI utility that allows users to perform common network diagnostic and configuration tasks via a simple interface. It includes options for:
    - Setting DNS servers to Google DNS.
    - Viewing network adapter information (e.g., MAC address, speed, IP).
    - Restarting network adapters.
    - Adjusting the speed and duplex settings of network adapters.
    - Resetting the network stack (IP configuration, DNS, Winsock).
    
    The script ensures that it runs with administrator privileges, automatically relaunching itself with elevated rights if necessary. It utilizes WPF and Windows Forms for creating an easy-to-use interface. A progress bar and status text provide real-time feedback during operations.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 0.1
    Tested On    : Windows 11 24H2
    Requirements :
        - Administrator privileges for network configuration.
        - .NET Framework for WPF and WinForms.
        - PowerShell 7+ or newer.
    
    Features:
    - **Set DNS Servers**: Set network adapters to use Google DNS (8.8.8.8, 8.8.4.4).
    - **Show Network Info**: Displays details of active network adapters such as MAC address, link speed, and IP address.
    - **Restart Network Adapters**: Disables and re-enables network adapters.
    - **Set Speed & Duplex**: Set the speed and duplex settings to "1.0 Gbps Full Duplex".
    - **Reset Network**: Releases and renews IP, flushes DNS cache, resets Winsock, and resets the IP stack.

    The script provides a simple, user-friendly interface and updates the status in real-time to guide the user through network troubleshooting tasks.

    **Important Note**: The tool is specifically designed to work on Windows systems requiring administrative access.
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
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Define XAML layout (style matched)
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Network Diagnostic &amp; Health Check Tool v0.1"
        Height="460" Width="460"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Background="#f4f4f4"
        FontFamily="Segoe UI"
        FontSize="12"
        SizeToContent="WidthAndHeight">
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
        <TextBlock Text="Network Diagnostic &amp; Health Check Tool v0.1" FontSize="16" FontWeight="Bold" Margin="0,0,0,20"
                   HorizontalAlignment="Center"/>
        <Button x:Name="SetDNSButton" Content="Set DNS Servers"/>
        <Button x:Name="ShowNetworkInfoButton" Content="Show Network Info"/>
        <Button x:Name="RestartNetworkButton" Content="Restart Network Adapters"/>
        <Button x:Name="SetSpeedDuplexButton" Content="Set Speed &amp; Duplex"/>
        <Button x:Name="ResetNetworkButton" Content="Reset Network"/>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="400" Minimum="0" Maximum="100" Margin="0,5,0,5" Value="0"/>
        <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="black"/>
        <TextBlock Text="Allester Padovani, Senior IT Specialist. All rights reserved." FontSize="12" FontStyle="Italic" Foreground="black" Margin="0,20,0,0" HorizontalAlignment="Center"/>
    </StackPanel>
</Window>
"@

# Load XAML UI
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get UI elements by name
$SetDNSButton = $window.FindName("SetDNSButton")
$ShowNetworkInfoButton = $window.FindName("ShowNetworkInfoButton")
$RestartNetworkButton = $window.FindName("RestartNetworkButton")
$SetSpeedDuplexButton = $window.FindName("SetSpeedDuplexButton")
$ResetNetworkButton = $window.FindName("ResetNetworkButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Helper to update UI and allow responsiveness
function Update-UI {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 150
}

# Enable or disable all buttons to prevent multiple clicks during operation
function Set-ButtonsEnabled($enabled) {
    $SetDNSButton.IsEnabled = $enabled
    $ShowNetworkInfoButton.IsEnabled = $enabled
    $RestartNetworkButton.IsEnabled = $enabled
    $SetSpeedDuplexButton.IsEnabled = $enabled
    $ResetNetworkButton.IsEnabled = $enabled
}

# Set DNS Servers button logic
$SetDNSButton.Add_Click({
    Set-ButtonsEnabled $false
    $StatusText.Text = "Setting DNS servers to Google DNS (8.8.8.8, 8.8.4.4)..."
    $ProgressBar.Value = 0
    Update-UI

    try {
        # Get all active Ethernet or Wi-Fi adapters
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and ($_.InterfaceDescription -match "Ethernet|Wi-Fi") }
        $count = 0
        $total = $adapters.Count
        $ProgressBar.Maximum = $total

        foreach ($adapter in $adapters) {
            $StatusText.Text = "Setting DNS on adapter: $($adapter.Name)"
            Update-UI

            # Set DNS servers on adapter to Google DNS (change if you want)
            Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses ("8.8.8.8","8.8.4.4") -ErrorAction Stop

            $count++
            $ProgressBar.Value = $count
        }

        $StatusText.Text = "DNS servers set on $count adapters."
    } catch {
        $StatusText.Text = "Error setting DNS: $($_.Exception.Message)"
    }

    Set-ButtonsEnabled $true
})

# Show Network Info button logic
$ShowNetworkInfoButton.Add_Click({
    Set-ButtonsEnabled $false
    $StatusText.Text = "Gathering network information..."
    $ProgressBar.Value = 0
    Update-UI

    try {
        $startButton.IsEnabled = $false
        $statusText.Text = "Scanning network adapters..."
        $progressBar.Value = 0
        [System.Windows.Forms.Application]::DoEvents()

        # Get physical network adapters that are up
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface } |
            Select-Object Name, Status, MacAddress, LinkSpeed, InterfaceDescription, InterfaceIndex

        # Get valid IPv4 addresses (exclude link-local)
        $ipv4Addresses = Get-NetIPAddress | Where-Object {
            $_.AddressFamily -eq 'IPv4' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.IPAddress -ne $null
        }

        $total = if ($adapters) { $adapters.Count } else { 0 }
        if ($total -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No active physical network adapters found.", "No Adapters", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $statusText.Text = "No adapters detected."
            return
        }

        $count = 0
        $result = ""
        foreach ($adapter in $adapters) {
            $count++
            $statusText.Text = "Processing: $($adapter.Name) ($count of $total)"

            if ($total -gt 0) {
                $progressBar.Value = [math]::Round(($count / $total) * 100)
            }
            [System.Windows.Forms.Application]::DoEvents()

            $ips = $ipv4Addresses | Where-Object { $_.InterfaceIndex -eq $adapter.InterfaceIndex } | Select-Object -ExpandProperty IPAddress
            $mainIp = if ($ips) { $ips[0] } else { "No IPv4 Address" }

            $result += "Name: $($adapter.Name)`n"
            $result += "Status: $($adapter.Status)`n"
            $result += "MAC: $($adapter.MacAddress)`n"
            $result += "Speed: $($adapter.LinkSpeed)`n"
            $result += "Description: $($adapter.InterfaceDescription)`n"
            $result += "Main IPv4 Address: $mainIp`n`n"
        }

        $progressBar.Value = 100
        $statusText.Text = "Scan complete."

        [System.Windows.Forms.MessageBox]::Show(
            $result,
            "Active Network Adapters",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred during scan: $($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        $statusText.Text = "Error occurred."
    }
    finally {
        $startButton.IsEnabled = $true
    }
})

# Restart Network Adapters button logic
$RestartNetworkButton.Add_Click({
    Set-ButtonsEnabled $false
    $StatusText.Text = "Restarting network adapters..."
    $ProgressBar.Value = 0
    Update-UI

    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.HardwareInterface }
        $total = $adapters.Count
        $count = 0
        $ProgressBar.Maximum = $total

        foreach ($adapter in $adapters) {
            $StatusText.Text = "Restarting adapter: $($adapter.Name)"
            Update-UI

            # Disable then enable the adapter to restart it
            Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2
            Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2

            $count++
            $ProgressBar.Value = $count
        }

        $StatusText.Text = "Restarted $count network adapters."
    } catch {
        $StatusText.Text = "Error restarting adapters: $($_.Exception.Message)"
    }

    Set-ButtonsEnabled $true
})

# Set Speed & Duplex button logic (your original code, improved)
$SetSpeedDuplexButton.Add_Click({
    Set-ButtonsEnabled $false
    $StatusText.Text = "Setting Speed & Duplex on adapters..."
    $ProgressBar.Value = 0
    Update-UI

    try {
        $adapters = Get-NetAdapter | Where-Object { $_.HardwareInterface -eq $true }
        $total = $adapters.Count
        $count = 0
        $ProgressBar.Maximum = $total

        foreach ($adapter in $adapters) {
            $StatusText.Text = "Processing adapter: $($adapter.Name)"
            Update-UI

            $advancedProps = Get-NetAdapterAdvancedProperty -Name $adapter.Name
            $speedDuplexProp = $advancedProps | Where-Object { $_.DisplayName -match 'Speed.*Duplex' }

            if ($speedDuplexProp) {
                $desiredValue = "1.0 Gbps Full Duplex"
                if ($speedDuplexProp.DisplayValue -ne $desiredValue) {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $speedDuplexProp.DisplayName -DisplayValue $desiredValue -NoRestart
                }
            } else {
                $StatusText.Text = "No Speed & Duplex property found for adapter: $($adapter.Name)"
                Update-UI
            }
            $count++
            $ProgressBar.Value = $count
        }

        $StatusText.Text = "Speed & Duplex set on $count adapters."
    } catch {
        $StatusText.Text = "Error setting Speed & Duplex: $($_.Exception.Message)"
    }

    Set-ButtonsEnabled $true
})

# Reset Network button logic
$ResetNetworkButton.Add_Click({
    Set-ButtonsEnabled $false
    $StatusText.Text = "Resetting network..."
    $ProgressBar.Value = 0
    Update-UI

    try {
        ipconfig /release | Out-Null
        $StatusText.Text = "Released IP..."
        Update-UI

        ipconfig /renew | Out-Null
        $StatusText.Text = "Renewed IP..."
        Update-UI

        ipconfig /flushdns | Out-Null
        $StatusText.Text = "Flushed DNS..."
        Update-UI

        netsh winsock reset | Out-Null
        $StatusText.Text = "Winsock reset done."
        Update-UI

        netsh int ip reset | Out-Null
        $StatusText.Text = "IP stack reset done."
        Update-UI

        $StatusText.Text = "Network reset complete. Please restart your computer."
    } catch {
        $StatusText.Text = "Error during network reset: $($_.Exception.Message)"
    }

    Set-ButtonsEnabled $true
})

# Show the main window
$window.ShowDialog() | Out-Null
