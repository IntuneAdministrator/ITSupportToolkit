<#
.SYNOPSIS
    GUI-based PowerShell dashboard for accessing Windows 11 sound settings.

.DESCRIPTION
    This script launches a WPF-based graphical interface that presents individual buttons for various
    sound-related settings in Windows 11. Options include Volume Mixer, Sound, Sound Devices, Default
    Microphone, and Default Audio Output. Each button opens the corresponding `ms-settings:` URI and
    logs the action to the Windows Event Log under the Application log using a custom event source.

    The interface is arranged in a clean two-column layout, optimized for clarity and quick access.
    This tool is ideal for IT professionals or end users who need centralized access to common
    sound configuration pages. Admin rights are required to create the event log source on first run.

.NOTES
    Author       : Allester Padovani  
    Date         : July 19, 2025  
    Version      : 1.1  
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
    $source = "PowerShell - Sound Settings Dashboard"

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
$window.Title = "Sound Settings Dashboard"
$window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
$window.SizeToContent = 'WidthAndHeight'  # This line auto-sizes the window

# Main vertical StackPanel
$mainPanel = New-Object System.Windows.Controls.StackPanel
$mainPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical
$mainPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainPanel.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
$mainPanel.Margin = [System.Windows.Thickness]::new(10)
$window.Content = $mainPanel

# Header
$textBlockHeader = New-Object System.Windows.Controls.TextBlock
$textBlockHeader.Text = "Sound Settings Dashboard"
$textBlockHeader.FontSize = 16
$textBlockHeader.FontWeight = [System.Windows.FontWeights]::Bold
$textBlockHeader.TextAlignment = [System.Windows.TextAlignment]::Center
$textBlockHeader.Margin = [System.Windows.Thickness]::new(0,0,0,20)
$mainPanel.Children.Add($textBlockHeader)

# Grid for buttons (2 columns)
$gridButtons = New-Object System.Windows.Controls.Grid
$gridButtons.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$gridButtons.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
$gridButtons.Width = 660

# Add 2 columns
for ($i=0; $i -lt 2; $i++) {
    $colDef = New-Object System.Windows.Controls.ColumnDefinition
    $colDef.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $gridButtons.ColumnDefinitions.Add($colDef)
}

# Helper: Add button to Grid
function Add-ButtonToGrid {
    param(
        [System.Windows.Controls.Button]$btn,
        [int]$row,
        [int]$col
    )
    $btn.Width = 320
    $btn.Margin = [System.Windows.Thickness]::new(5)
    [System.Windows.Controls.Grid]::SetRow($btn, $row)
    [System.Windows.Controls.Grid]::SetColumn($btn, $col)
    $gridButtons.Children.Add($btn) | Out-Null
}

# Define buttons and handlers
$buttonVolumeMixer = New-Object System.Windows.Controls.Button
$buttonVolumeMixer.Content = "Volume mixer"
$buttonVolumeMixer.Add_Click({
    Start-Process "ms-settings:apps-volume"
    Log-Action "Opened 'Volume mixer'"
})

$buttonSound = New-Object System.Windows.Controls.Button
$buttonSound.Content = "Sound"
$buttonSound.Add_Click({
    Start-Process "ms-settings:sound"
    Log-Action "Opened 'Sound'"
})

$buttonSoundDevices = New-Object System.Windows.Controls.Button
$buttonSoundDevices.Content = "Sound devices"
$buttonSoundDevices.Add_Click({
    Start-Process "ms-settings:sound-devices"
    Log-Action "Opened 'Sound devices'"
})

$buttonDefaultMic = New-Object System.Windows.Controls.Button
$buttonDefaultMic.Content = "Default microphone"
$buttonDefaultMic.Add_Click({
    Start-Process "ms-settings:sound-defaultinputproperties"
    Log-Action "Opened 'Default microphone'"
})

$buttonDefaultAudioOutput = New-Object System.Windows.Controls.Button
$buttonDefaultAudioOutput.Content = "Default audio output"
$buttonDefaultAudioOutput.Add_Click({
    Start-Process "ms-settings:sound-defaultoutputproperties"
    Log-Action "Opened 'Default audio output'"
})

# Button list
$buttons = @(
    $buttonVolumeMixer,
    $buttonSound,
    $buttonSoundDevices,
    $buttonDefaultMic,
    $buttonDefaultAudioOutput
)

# Calculate rows needed
$rowsNeeded = [math]::Ceiling($buttons.Count / 2)

# Add rows
for ($i = 0; $i -lt $rowsNeeded; $i++) {
    $rowDef = New-Object System.Windows.Controls.RowDefinition
    $rowDef.Height = [System.Windows.GridLength]::Auto
    $gridButtons.RowDefinitions.Add($rowDef)
}

# Place buttons into grid
for ($i = 0; $i -lt $buttons.Count; $i++) {
    $row = [math]::Floor($i / 2)
    $col = $i % 2
    Add-ButtonToGrid -btn $buttons[$i] -row $row -col $col
}

# Add button grid
$mainPanel.Children.Add($gridButtons)

# Footer
$textBlockFooter = New-Object System.Windows.Controls.TextBlock
$textBlockFooter.Text = "Allester Padovani, Senior IT Specialist. All rights reserved."
$textBlockFooter.FontSize = 12
$textBlockFooter.FontStyle = [System.Windows.FontStyles]::Italic
$textBlockFooter.Foreground = [System.Windows.Media.Brushes]::Black
$textBlockFooter.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$textBlockFooter.Margin = [System.Windows.Thickness]::new(0,20,0,5)
$mainPanel.Children.Add($textBlockFooter)

# Show GUI
$window.ShowDialog()
