<#
.SYNOPSIS
    Displays the main IPv4 addresses of all active physical network adapters.

.DESCRIPTION
    Retrieves all physical network adapters currently up,
    gets their main IPv4 addresses (excluding link-local),
    and shows results in a styled WPF GUI.

.AUTHOR
    Allester Padovani - Senior IT Specialist
    Date: 2025-07-24
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load required assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define styled XAML layout with xmlns:x added
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Network IPv4 Scanner'
        Height='420' Width='480'
        ResizeMode='NoResize'
        WindowStartupLocation='CenterScreen'
        Background='#f4f4f4'
        FontFamily='Segoe UI'
        FontSize='12'
        SizeToContent='WidthAndHeight'
        ShowInTaskbar='True'>
    <Window.Resources>
        <Style TargetType='Button'>
            <Setter Property='Background' Value='#f4f4f4'/>
            <Setter Property='Foreground' Value='Black'/>
            <Setter Property='BorderBrush' Value='#cccccc'/>
            <Setter Property='BorderThickness' Value='1'/>
            <Setter Property='FontWeight' Value='Bold'/>
            <Setter Property='Cursor' Value='Hand'/>
            <Setter Property='Width' Value='420'/>
            <Setter Property='Height' Value='30'/>
            <Setter Property='Margin' Value='0,0,0,10'/>
        </Style>
    </Window.Resources>
    <StackPanel Margin='20' HorizontalAlignment='Center'>
        <TextBlock Text='Network Adapter IPv4 Viewer' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='StartButton' Content='Start IPv4 Scan'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='420' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Click Start Scan to begin.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load the XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Access UI elements
$startButton = $window.FindName("StartButton")
$progressBar = $window.FindName("ProgressBar")
$statusText = $window.FindName("StatusText")

# Add scan logic
$startButton.Add_Click({
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

# Show the WPF window
$window.ShowDialog() | Out-Null
