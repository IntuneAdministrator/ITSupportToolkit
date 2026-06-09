<#
.SYNOPSIS
    WPF GUI with a single button for Network & Internet settings on Windows 11.

.DESCRIPTION
    This script creates a simple WPF-based graphical user interface (GUI) that contains a single button. 
    When clicked, the button opens the "Network & Internet" settings page on Windows 11 using the ms-settings URI.
    The interface includes a title and footer, and is designed to be minimalistic and user-friendly.

    The button triggers the opening of the "Network & Internet" settings and logs the action in the script 
    for auditing or debugging purposes. The window is centered on the screen and resizes automatically based 
    on the content.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2  
    Requirements : PowerShell 5.1+, Windows 11 24H2
    Usage        : Run the script, click the "Network & Internet" button, and the settings window will open.
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
$window.Title = "Network & Internet Settings"
$window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
$window.SizeToContent = 'WidthAndHeight'  # Auto-size to fit all content

# Main vertical stack panel
$mainStack = New-Object System.Windows.Controls.StackPanel
$mainStack.Orientation = [System.Windows.Controls.Orientation]::Vertical
$mainStack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$window.Content = $mainStack

# Header text block
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Network & Internet Settings"
$header.FontSize = 16
$header.FontWeight = [System.Windows.FontWeights]::Bold
$header.TextAlignment = [System.Windows.TextAlignment]::Center
$header.Margin = [System.Windows.Thickness]::new(0, 0, 0, 20)
$mainStack.Children.Add($header)

# Two-column container panel (No buttons left)
$columnsPanel = New-Object System.Windows.Controls.StackPanel
$columnsPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$columnsPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainStack.Children.Add($columnsPanel)

# Left column panel (Now only one button)
$leftColumn = New-Object System.Windows.Controls.StackPanel
$leftColumn.Orientation = [System.Windows.Controls.Orientation]::Vertical
$leftColumn.Margin = [System.Windows.Thickness]::new(10, 0, 10, 0)
$columnsPanel.Children.Add($leftColumn)

# Define buttons - LEFT COLUMN (Only the "Network & Internet" button)
$buttonsLeft = @(
    @{ Label = "Network & Internet"; Uri = "ms-settings:network-status" }
)

foreach ($item in $buttonsLeft) {
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $item.Label
    $btn.Width = 330
    $btn.Margin = [System.Windows.Thickness]::new(10)
    $btn.Add_Click({
        Start-Process $item.Uri
        Log-Action "Opened $($item.Label) settings"
    })
    $leftColumn.Children.Add($btn)
}

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
