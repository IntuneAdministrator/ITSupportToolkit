<#
.SYNOPSIS
    GUI-based PowerShell dashboard for accessing Windows 11 personalization settings.

.DESCRIPTION
    This script launches a WPF-based graphical interface that displays a two-column layout of buttons, 
    each linked to a specific Windows 11 personalization setting. The interface includes options such as 
    Background, Themes, Lock Screen, and Start Folders. Each button opens the associated `ms-settings:` 
    URI, and logs the action to the console for auditing or feedback purposes.

    The layout is clean and structured, making it ideal for use by IT support personnel or end users 
    needing quick access to appearance-related configuration pages in Windows. No internet connection 
    is required, but administrative permissions may be needed depending on system policy restrictions.

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

# Main window setup
$window = New-Object System.Windows.Window
$window.Title = "Personalization Settings"
# Remove fixed Width and Height to allow auto-sizing
$window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen

# Let window size itself based on content
$window.SizeToContent = 'WidthAndHeight'

# Main vertical StackPanel
$mainStack = New-Object System.Windows.Controls.StackPanel
$mainStack.Orientation = [System.Windows.Controls.Orientation]::Vertical
$mainStack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$window.Content = $mainStack

# Header TextBlock
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Personalization Settings"
$header.FontSize = 16
$header.FontWeight = [System.Windows.FontWeights]::Bold
$header.TextAlignment = [System.Windows.TextAlignment]::Center
$header.Margin = [System.Windows.Thickness]::new(0, 0, 0, 20)
$mainStack.Children.Add($header)

# Two-column panel container
$columnsPanel = New-Object System.Windows.Controls.StackPanel
$columnsPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$columnsPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainStack.Children.Add($columnsPanel)

# Left column
$leftColumn = New-Object System.Windows.Controls.StackPanel
$leftColumn.Orientation = [System.Windows.Controls.Orientation]::Vertical
$leftColumn.Margin = [System.Windows.Thickness]::new(10, 0, 10, 0)
$columnsPanel.Children.Add($leftColumn)

# Right column
$rightColumn = New-Object System.Windows.Controls.StackPanel
$rightColumn.Orientation = [System.Windows.Controls.Orientation]::Vertical
$rightColumn.Margin = [System.Windows.Thickness]::new(10, 0, 10, 0)
$columnsPanel.Children.Add($rightColumn)

# Left column buttons (removed: Colors, Customize Copilot Key, Dynamic Lighting, Fonts, Glance)

$btnBackground = New-Object System.Windows.Controls.Button
$btnBackground.Content = "Background"
$btnBackground.Width = 330
$btnBackground.Margin = [System.Windows.Thickness]::new(10)
$btnBackground.Add_Click({
    Start-Process "ms-settings:personalization-background"
    Log-Action "Opened Background settings"
})
$leftColumn.Children.Add($btnBackground)

$btnStartFolders = New-Object System.Windows.Controls.Button
$btnStartFolders.Content = "Choose Folders on Start"
$btnStartFolders.Width = 330
$btnStartFolders.Margin = [System.Windows.Thickness]::new(10)
$btnStartFolders.Add_Click({
    Start-Process "ms-settings:personalization-start-places"
    Log-Action "Opened Choose Folders on Start settings"
})
$leftColumn.Children.Add($btnStartFolders)

# Right column buttons (removed: Navigation Bar, Personalization, Start, Taskbar, Text Input, Touch Keyboard)

$btnLockScreen = New-Object System.Windows.Controls.Button
$btnLockScreen.Content = "Lock Screen"
$btnLockScreen.Width = 330
$btnLockScreen.Margin = [System.Windows.Thickness]::new(10)
$btnLockScreen.Add_Click({
    Start-Process "ms-settings:lockscreen"
    Log-Action "Opened Lock Screen settings"
})
$rightColumn.Children.Add($btnLockScreen)

$btnThemes = New-Object System.Windows.Controls.Button
$btnThemes.Content = "Themes"
$btnThemes.Width = 330
$btnThemes.Margin = [System.Windows.Thickness]::new(10)
$btnThemes.Add_Click({
    Start-Process "ms-settings:themes"
    Log-Action "Opened Themes settings"
})
$rightColumn.Children.Add($btnThemes)

# Footer TextBlock
$footer = New-Object System.Windows.Controls.TextBlock
$footer.Text = "Allester Padovani, Senior IT Specialist. All rights reserved."
$footer.FontSize = 12
$footer.FontStyle = [System.Windows.FontStyles]::Italic
$footer.Foreground = [System.Windows.Media.Brushes]::Black
$footer.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$footer.Margin = [System.Windows.Thickness]::new(0, 20, 0, 5)
$mainStack.Children.Add($footer)

# Show window
$window.ShowDialog()
