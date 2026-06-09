<#
.SYNOPSIS
    GUI-based PowerShell dashboard for accessing Windows 11 device and input settings.

.DESCRIPTION
    This script creates a WPF-based graphical interface with a two-column layout of buttons, 
    each linked to a specific Windows 11 device or input setting. These buttons cover settings 
    like AutoPlay, Bluetooth, Connected Devices, Default Camera, USB devices, Printers & Scanners, 
    and Your Phone.

    Each button opens the corresponding `ms-settings:` URI and logs the action in the console for feedback.

    This tool provides IT support staff or end users with an easy and quick way to access critical device 
    and input-related configuration pages in Windows 11. The layout is designed for efficiency and ease of use.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2  
    Requirements : PowerShell 5.1+, .NET Framework (for WPF)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

function Log-Action {
    param ([string]$message)
    Write-Host "[LOG] $message"
}

# Create main window
$window = New-Object System.Windows.Window
$window.Title = "Windows 11 Device & Input Settings"
$window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
$window.SizeToContent = 'WidthAndHeight'

# Main vertical stack panel
$mainStack = New-Object System.Windows.Controls.StackPanel
$mainStack.Orientation = [System.Windows.Controls.Orientation]::Vertical
$mainStack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$window.Content = $mainStack

# Header text block
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Device & Input Settings"
$header.FontSize = 16
$header.FontWeight = [System.Windows.FontWeights]::Bold
$header.TextAlignment = [System.Windows.TextAlignment]::Center
$header.Margin = [System.Windows.Thickness]::new(0, 0, 0, 20)
$mainStack.Children.Add($header)

# Two-column container panel
$columnsPanel = New-Object System.Windows.Controls.StackPanel
$columnsPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$columnsPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainStack.Children.Add($columnsPanel)

# Left column panel
$leftColumn = New-Object System.Windows.Controls.StackPanel
$leftColumn.Orientation = [System.Windows.Controls.Orientation]::Vertical
$leftColumn.Margin = [System.Windows.Thickness]::new(10, 0, 10, 0)
$columnsPanel.Children.Add($leftColumn)

# Right column panel
$rightColumn = New-Object System.Windows.Controls.StackPanel
$rightColumn.Orientation = [System.Windows.Controls.Orientation]::Vertical
$rightColumn.Margin = [System.Windows.Thickness]::new(10, 0, 10, 0)
$columnsPanel.Children.Add($rightColumn)

# Left Column Buttons

$buttonAutoPlay = New-Object System.Windows.Controls.Button
$buttonAutoPlay.Content = "AutoPlay"
$buttonAutoPlay.Width = 320
$buttonAutoPlay.Margin = [System.Windows.Thickness]::new(10)
$buttonAutoPlay.Add_Click({
    Start-Process "ms-settings:autoplay"
    Log-Action "Opened AutoPlay settings"
})
$leftColumn.Children.Add($buttonAutoPlay)

$buttonBluetooth = New-Object System.Windows.Controls.Button
$buttonBluetooth.Content = "Bluetooth"
$buttonBluetooth.Width = 320
$buttonBluetooth.Margin = [System.Windows.Thickness]::new(10)
$buttonBluetooth.Add_Click({
    Start-Process "ms-settings:bluetooth"
    Log-Action "Opened Bluetooth settings"
})
$leftColumn.Children.Add($buttonBluetooth)

$buttonConnectedDevices = New-Object System.Windows.Controls.Button
$buttonConnectedDevices.Content = "Connected Devices"
$buttonConnectedDevices.Width = 320
$buttonConnectedDevices.Margin = [System.Windows.Thickness]::new(10)
$buttonConnectedDevices.Add_Click({
    Start-Process "ms-settings:connecteddevices"
    Log-Action "Opened Connected Devices settings"
})
$leftColumn.Children.Add($buttonConnectedDevices)

$buttonDefaultCamera = New-Object System.Windows.Controls.Button
$buttonDefaultCamera.Content = "Default Camera"
$buttonDefaultCamera.Width = 320
$buttonDefaultCamera.Margin = [System.Windows.Thickness]::new(10)
$buttonDefaultCamera.Add_Click({
    Start-Process "ms-settings:camera"
    Log-Action "Opened Default Camera settings"
})
$leftColumn.Children.Add($buttonDefaultCamera)

# Right Column Buttons

$buttonUSB = New-Object System.Windows.Controls.Button
$buttonUSB.Content = "USB"
$buttonUSB.Width = 320
$buttonUSB.Margin = [System.Windows.Thickness]::new(10)
$buttonUSB.Add_Click({
    Start-Process "ms-settings:usb"
    Log-Action "Opened USB settings"
})
$rightColumn.Children.Add($buttonUSB)

$buttonPrintersScanners = New-Object System.Windows.Controls.Button
$buttonPrintersScanners.Content = "Printers & Scanners"
$buttonPrintersScanners.Width = 320
$buttonPrintersScanners.Margin = [System.Windows.Thickness]::new(10)
$buttonPrintersScanners.Add_Click({
    Start-Process "ms-settings:printers"
    Log-Action "Opened Printers & Scanners settings"
})
$rightColumn.Children.Add($buttonPrintersScanners)

$buttonYourPhone = New-Object System.Windows.Controls.Button
$buttonYourPhone.Content = "Your Phone"
$buttonYourPhone.Width = 320
$buttonYourPhone.Margin = [System.Windows.Thickness]::new(10)
$buttonYourPhone.Add_Click({
    Start-Process "ms-settings:mobile-devices"
    Log-Action "Opened Your Phone settings"
})
$rightColumn.Children.Add($buttonYourPhone)

# Footer text
$footer = New-Object System.Windows.Controls.TextBlock
$footer.Text = "Allester Padovani, Senior IT Specialist. All rights reserved."
$footer.FontSize = 12
$footer.FontStyle = [System.Windows.FontStyles]::Italic
$footer.Foreground = [System.Windows.Media.Brushes]::Black
$footer.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$footer.Margin = [System.Windows.Thickness]::new(0, 20, 0, 5)
$mainStack.Children.Add($footer)

# Show the window
$window.ShowDialog()
