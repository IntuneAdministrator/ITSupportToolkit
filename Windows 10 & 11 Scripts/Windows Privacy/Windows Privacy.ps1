<#
.SYNOPSIS
    Interactive WPF-based PowerShell GUI to manage privacy settings on Windows 11 24H2.

.DESCRIPTION
    This script uses Windows Presentation Foundation (WPF) to create a simple vertical layout GUI
    that provides buttons for managing various privacy settings in Windows 11 24H2. Each button is 
    tied to a specific ms-settings URI, and clicking a button will open the corresponding settings page 
    in the Windows Settings app. Additionally, every action is logged to the Windows Event Log for auditing purposes.

    The user interface is built with a clean and simple design, with a header, a list of privacy buttons, 
    and a footer containing credits. The UI is fully functional and can be customized by modifying the button list.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2  
    Requirements : PowerShell 5.1+, admin rights for event log creation, and Windows 11 24H2+
    Usage        : Launch the script, click the desired privacy setting button, and the corresponding 
                   settings page will open.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

function Log-Action {
    param ([string]$message)

    $logName = "Application"
    $source = "PowerShell - Privacy Settings Dashboard"

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
$window.Title = "Privacy Settings Dashboard"
$window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
$window.SizeToContent = 'WidthAndHeight'

# Main vertical StackPanel to hold header, grid buttons, footer
$mainPanel = New-Object System.Windows.Controls.StackPanel
$mainPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical
$mainPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$mainPanel.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
$mainPanel.Margin = [System.Windows.Thickness]::new(10)
$window.Content = $mainPanel

# Header TextBlock
$textBlockHeader = New-Object System.Windows.Controls.TextBlock
$textBlockHeader.Text = "Privacy Settings Dashboard"
$textBlockHeader.FontSize = 16
$textBlockHeader.FontWeight = [System.Windows.FontWeights]::Bold
$textBlockHeader.TextAlignment = [System.Windows.TextAlignment]::Center
$textBlockHeader.Margin = [System.Windows.Thickness]::new(0,0,0,20)
$mainPanel.Children.Add($textBlockHeader)

# Create a Grid for buttons with 1 column (since we removed Contacts button)
$gridButtons = New-Object System.Windows.Controls.Grid
$gridButtons.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$gridButtons.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
$gridButtons.Width = 320  # Single column

# Define 1 column
$colDef = New-Object System.Windows.Controls.ColumnDefinition
$colDef.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
$gridButtons.ColumnDefinitions.Add($colDef)

# Helper function to add button to grid at row and column
function Add-ButtonToGrid {
    param(
        [System.Windows.Controls.Button]$btn,
        [int]$row
    )
    $btn.Width = 320
    $btn.Margin = [System.Windows.Thickness]::new(5)
    [System.Windows.Controls.Grid]::SetRow($btn, $row)
    $gridButtons.Children.Add($btn) | Out-Null
}

# Define all buttons (removed Contacts)
$buttonAccountInfo = New-Object System.Windows.Controls.Button
$buttonAccountInfo.Content = "Account info"
$buttonAccountInfo.Add_Click({
    Start-Process "ms-settings:privacy-accountinfo"
    Log-Action "Opened 'Account info'"
})

$buttonCamera = New-Object System.Windows.Controls.Button
$buttonCamera.Content = "Camera"
$buttonCamera.Add_Click({
    Start-Process "ms-settings:privacy-webcam"
    Log-Action "Opened 'Camera'"
})

$buttonMicrophone = New-Object System.Windows.Controls.Button
$buttonMicrophone.Content = "Microphone"
$buttonMicrophone.Add_Click({
    Start-Process "ms-settings:privacy-microphone"
    Log-Action "Opened 'Microphone'"
})

# Collect remaining buttons
$buttons = @(
    $buttonAccountInfo,
    $buttonCamera,
    $buttonMicrophone
)

# Add rows to grid (1 button per row)
for ($i = 0; $i -lt $buttons.Count; $i++) {
    $rowDef = New-Object System.Windows.Controls.RowDefinition
    $rowDef.Height = [System.Windows.GridLength]::Auto
    $gridButtons.RowDefinitions.Add($rowDef)
}

# Add buttons to grid at calculated row
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
