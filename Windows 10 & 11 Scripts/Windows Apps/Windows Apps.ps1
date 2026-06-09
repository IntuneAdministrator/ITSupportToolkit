<#
.SYNOPSIS
    WPF GUI for accessing Windows 11 Apps & Features settings with a two-column button layout.

.DESCRIPTION
    This script provides a graphical interface (WPF-based) with two columns of buttons for accessing 
    various Windows 11 Apps & Features settings. Each button opens the corresponding `ms-settings:` URI, 
    such as Apps & Features, Apps for websites, Manage optional features, and Startup apps.

    The buttons have consistent width and styling to provide a user-friendly interface for managing apps and 
    features in Windows 11. Each button action is logged in the Windows Event Log for tracking.

    Designed for ease of use, this tool simplifies navigating to important settings for device management, 
    optional features, and app configurations.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.2  
    Tested On    : Windows 11 24H2  
    Requirements : PowerShell 5.1+, .NET Framework (for WPF)
    Log Action   : Logs actions to the Windows Event Log under 'Application' log as 'PowerShell - AppsFeatures Settings Launcher'.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

function Log-Action {
    param ([string]$message)
    $logName = "Application"
    $source = "PowerShell - AppsFeatures Settings Launcher"
    if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
        try { New-EventLog -LogName $logName -Source $source } catch { Write-Warning "Run as Admin to create event log source." }
    }
    Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message $message
}

$window = New-Object System.Windows.Window
$window.Title = "Windows Apps & Features Settings"
$window.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
$window.ResizeMode = [System.Windows.ResizeMode]::CanMinimize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen

# Main vertical stack panel for header + content + footer
$mainStack = New-Object System.Windows.Controls.StackPanel
$mainStack.Orientation = [System.Windows.Controls.Orientation]::Vertical
$mainStack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$window.Content = $mainStack

# Header
$textBlockHeader = New-Object System.Windows.Controls.TextBlock
$textBlockHeader.Text = "Windows Apps & Features Settings"
$textBlockHeader.FontSize = 16
$textBlockHeader.FontWeight = [System.Windows.FontWeights]::Bold
$textBlockHeader.TextAlignment = [System.Windows.TextAlignment]::Center
$textBlockHeader.Margin = [System.Windows.Thickness]::new(0, 0, 0, 20)
$mainStack.Children.Add($textBlockHeader)

# Horizontal stack panel to hold two vertical button columns
$buttonColumnsPanel = New-Object System.Windows.Controls.StackPanel
$buttonColumnsPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
$buttonColumnsPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainStack.Children.Add($buttonColumnsPanel)

# Left Column stack panel
$leftColumn = New-Object System.Windows.Controls.StackPanel
$leftColumn.Orientation = [System.Windows.Controls.Orientation]::Vertical
$leftColumn.Margin = [System.Windows.Thickness]::new(10, 0, 10, 0)
$buttonColumnsPanel.Children.Add($leftColumn)

# Right Column stack panel
$rightColumn = New-Object System.Windows.Controls.StackPanel
$rightColumn.Orientation = [System.Windows.Controls.Orientation]::Vertical
$rightColumn.Margin = [System.Windows.Thickness]::new(10, 0, 10, 0)
$buttonColumnsPanel.Children.Add($rightColumn)

# Fixed width for all buttons
$fixedButtonWidth = 320

# === Left Column Buttons ===

$buttonAppsFeatures = New-Object System.Windows.Controls.Button
$buttonAppsFeatures.Content = "Apps & Features"
$buttonAppsFeatures.Margin = [System.Windows.Thickness]::new(10)
$buttonAppsFeatures.Width = $fixedButtonWidth
$buttonAppsFeatures.Add_Click({
    Start-Process "ms-settings:appsfeatures"
    Log-Action "Opened Apps & Features"
})
$leftColumn.Children.Add($buttonAppsFeatures)

$buttonAppsForWebsites = New-Object System.Windows.Controls.Button
$buttonAppsForWebsites.Content = "Apps for websites"
$buttonAppsForWebsites.Margin = [System.Windows.Thickness]::new(10)
$buttonAppsForWebsites.Width = $fixedButtonWidth
$buttonAppsForWebsites.Add_Click({
    Start-Process "ms-settings:appsforwebsites"
    Log-Action "Opened Apps for websites"
})
$leftColumn.Children.Add($buttonAppsForWebsites)

# === Right Column Buttons ===

$buttonManageOptionalFeatures = New-Object System.Windows.Controls.Button
$buttonManageOptionalFeatures.Content = "Manage optional features"
$buttonManageOptionalFeatures.Margin = [System.Windows.Thickness]::new(10)
$buttonManageOptionalFeatures.Width = $fixedButtonWidth
$buttonManageOptionalFeatures.Add_Click({
    Start-Process "ms-settings:optionalfeatures"
    Log-Action "Opened Manage optional features"
})
$rightColumn.Children.Add($buttonManageOptionalFeatures)

$buttonStartupApps = New-Object System.Windows.Controls.Button
$buttonStartupApps.Content = "Startup apps"
$buttonStartupApps.Margin = [System.Windows.Thickness]::new(10)
$buttonStartupApps.Width = $fixedButtonWidth
$buttonStartupApps.Add_Click({
    Start-Process "ms-settings:startupapps"
    Log-Action "Opened Startup apps"
})
$rightColumn.Children.Add($buttonStartupApps)

# Footer
$textBlockFooter = New-Object System.Windows.Controls.TextBlock
$textBlockFooter.Text = "Allester Padovani, Senior IT Specialist. All rights reserved."
$textBlockFooter.FontSize = 12
$textBlockFooter.FontStyle = [System.Windows.FontStyles]::Italic
$textBlockFooter.Foreground = [System.Windows.Media.Brushes]::Black
$textBlockFooter.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$textBlockFooter.Margin = [System.Windows.Thickness]::new(0, 20, 0, 5)
$mainStack.Children.Add($textBlockFooter)

# Show the window
$window.ShowDialog()
