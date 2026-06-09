<#
.SYNOPSIS
    GUI-based PowerShell dashboard for accessing common Windows 11 system settings.

.DESCRIPTION
    This script launches a WPF-based graphical interface that provides individual buttons for quickly 
    opening key Windows system settings pages such as About, Display, and Power & Sleep. Each button 
    launches its corresponding `ms-settings:` URI and logs the action to the Windows Event Log under 
    the "Application" log using a custom event source.

    The tool provides a centralized, user-friendly interface for users and IT staff to access and review 
    system configuration areas. Administrative rights are required if the event log source does not already exist.

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
    $source = "PowerShell - System Settings Dashboard"

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
$window.Title = "System Settings Dashboard"
$window.SizeToContent = 'WidthAndHeight'
$window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen

# Main vertical StackPanel (this is where buttons will be stacked vertically)
$mainPanel = New-Object System.Windows.Controls.StackPanel
$mainPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical
$mainPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainPanel.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
$mainPanel.Margin = [System.Windows.Thickness]::new(10)
$window.Content = $mainPanel

# Header TextBlock
$textBlockHeader = New-Object System.Windows.Controls.TextBlock
$textBlockHeader.Text = "System Settings Dashboard"
$textBlockHeader.FontSize = 18
$textBlockHeader.FontWeight = [System.Windows.FontWeights]::Bold
$textBlockHeader.TextAlignment = [System.Windows.TextAlignment]::Center
$textBlockHeader.Margin = [System.Windows.Thickness]::new(0,0,0,20)
$mainPanel.Children.Add($textBlockHeader)

# Define each button individually with event handlers

# About
$buttonAbout = New-Object System.Windows.Controls.Button
$buttonAbout.Content = "About"
$buttonAbout.Margin = [System.Windows.Thickness]::new(0,0,0,10)  # Added bottom margin for space
$buttonAbout.Add_Click({
    Start-Process "ms-settings:about"
    Log-Action "Opened 'About'"
})

# Display
$buttonDisplay = New-Object System.Windows.Controls.Button
$buttonDisplay.Content = "Display"
$buttonDisplay.Margin = [System.Windows.Thickness]::new(0,0,0,10)  # Added bottom margin for space
$buttonDisplay.Add_Click({
    Start-Process "ms-settings:display"
    Log-Action "Opened 'Display'"
})

# Power & Sleep
$buttonPowerSleep = New-Object System.Windows.Controls.Button
$buttonPowerSleep.Content = "Power & Sleep"
$buttonPowerSleep.Margin = [System.Windows.Thickness]::new(0,0,0,10)  # Added bottom margin for space
$buttonPowerSleep.Add_Click({
    Start-Process "ms-settings:powersleep"
    Log-Action "Opened 'Power & Sleep'"
})

# Add all buttons to an array (order matches above)
$buttons = @(
    $buttonAbout,
    $buttonDisplay,
    $buttonPowerSleep
)

# Add buttons to the StackPanel (one above the other)
foreach ($button in $buttons) {
    $mainPanel.Children.Add($button)
}

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
