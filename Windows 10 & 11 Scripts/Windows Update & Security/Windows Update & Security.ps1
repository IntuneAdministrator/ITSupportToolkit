<#
.SYNOPSIS
    GUI-based PowerShell dashboard for accessing Windows 11 maintenance and troubleshooting settings.

.DESCRIPTION
    This script launches a WPF-based graphical interface that provides individual buttons for launching 
    key Windows maintenance settings, including Activation, Recovery, and Troubleshoot. Each button 
    uses a corresponding `ms-settings:` URI to open its target system page and logs the action 
    to the Windows Event Log under the "Application" log using a custom event source.

    The interface is designed with a clean, user-friendly layout and leverages WPF and Windows Forms 
    for rendering. This tool is intended for support staff or end users who need quick, centralized 
    access to common system maintenance functions. Administrative privileges are required to register 
    the event log source if it does not already exist.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2  
    Requirements : Admin rights, PowerShell 5.1+, .NET Framework (for WPF)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

function Log-Action {
    param ([string]$message)

    $logName = "Application"
    $source = "PowerShell - Windows Maintenance Dashboard"

    if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
        try {
            New-EventLog -LogName $logName -Source $source
        } catch {
            Write-Warning "Run the script as Administrator to create event log source."
        }
    }

    Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message $message
}

# Create main window
$window = New-Object System.Windows.Window
$window.Title = "Windows Maintenance Dashboard"
$window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
$window.SizeToContent = 'WidthAndHeight'

# Main vertical StackPanel
$mainPanel = New-Object System.Windows.Controls.StackPanel
$mainPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical
$mainPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainPanel.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
$mainPanel.Margin = [System.Windows.Thickness]::new(10)
$window.Content = $mainPanel

# Header TextBlock
$textBlockHeader = New-Object System.Windows.Controls.TextBlock
$textBlockHeader.Text = "Windows Maintenance Dashboard"
$textBlockHeader.FontSize = 18
$textBlockHeader.FontWeight = [System.Windows.FontWeights]::Bold
$textBlockHeader.TextAlignment = [System.Windows.TextAlignment]::Center
$textBlockHeader.Margin = [System.Windows.Thickness]::new(0,0,0,20)
$mainPanel.Children.Add($textBlockHeader)

# Create Grid for buttons with 1 column
$gridButtons = New-Object System.Windows.Controls.Grid
$gridButtons.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$gridButtons.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
#$gridButtons.Width = 580

# Define 1 column
$colDef = New-Object System.Windows.Controls.ColumnDefinition
$colDef.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
$gridButtons.ColumnDefinitions.Add($colDef)

function Add-ButtonToGrid {
    param(
        [System.Windows.Controls.Button]$btn,
        [int]$row
    )
    $btn.Width = 320
    $btn.Margin = [System.Windows.Thickness]::new(5)
    [System.Windows.Controls.Grid]::SetRow($btn, $row)
    [System.Windows.Controls.Grid]::SetColumn($btn, 0)
    $gridButtons.Children.Add($btn) | Out-Null
}

# Buttons definitions

$buttonActivation = New-Object System.Windows.Controls.Button
$buttonActivation.Content = "Activation"
$buttonActivation.Add_Click({
    Start-Process "ms-settings:activation"
    Log-Action "Opened 'Activation'"
})

$buttonRecovery = New-Object System.Windows.Controls.Button
$buttonRecovery.Content = "Recovery"
$buttonRecovery.Add_Click({
    Start-Process "ms-settings:recovery"
    Log-Action "Opened 'Recovery'"
})

$buttonTroubleshoot = New-Object System.Windows.Controls.Button
$buttonTroubleshoot.Content = "Troubleshoot"
$buttonTroubleshoot.Add_Click({
    Start-Process "ms-settings:troubleshoot"
    Log-Action "Opened 'Troubleshoot'"
})

# Collect all buttons in an array
$buttons = @(
    $buttonActivation,
    $buttonRecovery,
    $buttonTroubleshoot
)

# Calculate rows needed for 1 column
$rowsNeeded = $buttons.Count

# Add rows to grid
for ($i = 0; $i -lt $rowsNeeded; $i++) {
    $rowDef = New-Object System.Windows.Controls.RowDefinition
    $rowDef.Height = [System.Windows.GridLength]::Auto
    $gridButtons.RowDefinitions.Add($rowDef)
}

# Add buttons to grid with row positioning (only 1 column)
for ($i = 0; $i -lt $buttons.Count; $i++) {
    Add-ButtonToGrid -btn $buttons[$i] -row $i
}

# Add grid to main panel
$mainPanel.Children.Add($gridButtons)

# Footer TextBlock
$textBlockFooter = New-Object System.Windows.Controls.TextBlock
$textBlockFooter.Text = "Allester Padovani, Senior IT Specialist. All rights reserved."
$textBlockFooter.FontSize = 12
$textBlockFooter.FontStyle = [System.Windows.FontStyles]::Italic
$textBlockFooter.Foreground = [System.Windows.Media.Brushes]::Black
$textBlockFooter.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$textBlockFooter.Margin = [System.Windows.Thickness]::new(0,20,0,5)
$mainPanel.Children.Add($textBlockFooter)

# Show the GUI window
$window.ShowDialog()
