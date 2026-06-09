<#
.SYNOPSIS
    Restarts enabled Wi-Fi and Ethernet adapters using a WPF GUI.

.DESCRIPTION
    Detects enabled "Wi-Fi" and "Ethernet" adapters and disables then re-enables them.
    Provides a friendly GUI with progress and status messages.

.AUTHOR
    Name        : Allester Padovani
    Title       : Senior IT Specialist
    Date        : 2025-07-18
    Version     : 1.1 (with division-by-zero fix)
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
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define XAML layout (style matched)
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Network Adapter Restart Utility'
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
        <TextBlock Name='StatusText' Text='Network Adapter Restart Utility' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button Name='RestartButton' Content='Restart Adapters' HorizontalAlignment='Center'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock Name='StatusFooterText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>

</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Find controls
$statusText = $window.FindName("StatusText")
$statusFooterText = $window.FindName("StatusFooterText")
$progressBar = $window.FindName("ProgressBar")
$restartButton = $window.FindName("RestartButton")

function Show-MessageBox {
    param (
        [string]$Text,
        [string]$Title = "Network Adapter Restart Utility",
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    [System.Windows.Forms.MessageBox]::Show($Text, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, $Icon) | Out-Null
}

function Restart-Adapters {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Show-MessageBox -Text "Please run this tool as Administrator." -Title "Insufficient Privileges" -Icon ([System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $restartButton.IsEnabled = $false
    $statusText.Text = "Finding enabled Wi-Fi and Ethernet adapters..."
    $progressBar.Value = 10
    [System.Windows.Forms.Application]::DoEvents()

    $adapters = Get-NetAdapter | Where-Object {
        ($_.Name -eq "Wi-Fi" -or $_.Name -eq "Ethernet") -and
        ($_.Status -eq "Up" -or $_.Status -eq "Connected")
    }

    if (-not $adapters) {
        $statusText.Text = "No enabled Wi-Fi or Ethernet adapters found."
        Show-MessageBox -Text "No enabled Wi-Fi or Ethernet adapters found." -Title "No Adapters Found" -Icon ([System.Windows.Forms.MessageBoxIcon]::Warning)
        $progressBar.Value = 0
        $restartButton.IsEnabled = $true
        return
    }

    $total = $adapters.Count
    $count = 0

    foreach ($adapter in $adapters) {
        $statusText.Text = "Restarting adapter: $($adapter.Name)"
        Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3

        $count++

        # Safe division check to avoid divide-by-zero
        if ($total -gt 0) {
            $progressBar.Value = 10 + (($count / $total) * 80)
        } else {
            $progressBar.Value = 10
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    $statusText.Text = "Restart complete."
    $progressBar.Value = 100
    Show-MessageBox -Text "Selected adapters restarted successfully." -Title "Restart Complete" -Icon ([System.Windows.Forms.MessageBoxIcon]::Information)

    $progressBar.Value = 0
    $restartButton.IsEnabled = $true
}

# Wire button click event
$restartButton.Add_Click({
    Restart-Adapters
})

# Show the WPF window
$window.ShowDialog() | Out-Null
