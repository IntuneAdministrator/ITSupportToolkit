<#
.SYNOPSIS
    Windows 11 Work & Account Settings Launcher GUI with fixed-width buttons.

.DESCRIPTION
    This script creates a WPF-based graphical user interface (GUI) with two columns of buttons, 
    each having a fixed width of 320 pixels. Each button launches a specific Windows 11 ms-settings page 
    related to Work & Account settings.

    The layout is organized into a grid of buttons for easy navigation, each corresponding to a specific Work & Account setting page. 
    The script also logs the action of opening each setting in the Event Log.

    The GUI window is resizable with a minimal set of UI elements and styled with a clear header and footer.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.2  
    Tested On    : Windows 11 24H2  
    Requirements : PowerShell 5.1+, Windows 11 24H2
    Usage        : Run the script, click any button to open the corresponding Windows 11 Work & Account settings.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

function Log-Action {
    param (
        [string]$message
    )
    $logName = "Application"
    $source = "PowerShell - WorkAccount Settings Launcher"
    if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
        try { New-EventLog -LogName $logName -Source $source } catch { Write-Warning "Run as Admin to create event log source." }
    }
    Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message $message
}

# Create main WPF window
$window = New-Object System.Windows.Window
$window.Title = "Windows Account Settings"
$window.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
$window.ResizeMode = [System.Windows.ResizeMode]::CanMinimize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen

# Main vertical StackPanel container
$stackPanel = New-Object System.Windows.Controls.StackPanel
$stackPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical
$stackPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$stackPanel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
$window.Content = $stackPanel

# Header
$textBlockHeader = New-Object System.Windows.Controls.TextBlock
$textBlockHeader.Text = "Windows Account Settings"
$textBlockHeader.FontSize = 16
$textBlockHeader.FontWeight = [System.Windows.FontWeights]::Bold
$textBlockHeader.TextAlignment = [System.Windows.TextAlignment]::Center
$textBlockHeader.Margin = [System.Windows.Thickness]::new(0,0,0,20)
$stackPanel.Children.Add($textBlockHeader)

# Grid with 2 columns
$buttonGrid = New-Object System.Windows.Controls.Grid
$buttonGrid.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

$col1 = New-Object System.Windows.Controls.ColumnDefinition
$col2 = New-Object System.Windows.Controls.ColumnDefinition
$buttonGrid.ColumnDefinitions.Add($col1)
$buttonGrid.ColumnDefinitions.Add($col2)

function Add-ButtonToGrid {
    param(
        [System.Windows.Controls.Button]$btn,
        [int]$row,
        [int]$col
    )
    while ($buttonGrid.RowDefinitions.Count -le $row) {
        $rowDef = New-Object System.Windows.Controls.RowDefinition
        $rowDef.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto)
        $buttonGrid.RowDefinitions.Add($rowDef)
    }
    [System.Windows.Controls.Grid]::SetRow($btn, $row)
    [System.Windows.Controls.Grid]::SetColumn($btn, $col)
    $buttonGrid.Children.Add($btn) | Out-Null
}

$btnAccessWorkSchool = New-Object System.Windows.Controls.Button
$btnAccessWorkSchool.Content = "Access work or school"
$btnAccessWorkSchool.Width = 320
$btnAccessWorkSchool.Margin = [System.Windows.Thickness]::new(10)
$btnAccessWorkSchool.Add_Click({
    Start-Process "ms-settings:workplace"
    Log-Action "Opened 'Access work or school'"
})
Add-ButtonToGrid -btn $btnAccessWorkSchool -row 0 -col 0

$btnEmailAppAccounts = New-Object System.Windows.Controls.Button
$btnEmailAppAccounts.Content = "Email & app accounts"
$btnEmailAppAccounts.Width = 320
$btnEmailAppAccounts.Margin = [System.Windows.Thickness]::new(10)
$btnEmailAppAccounts.Add_Click({
    Start-Process "ms-settings:emailandaccounts"
    Log-Action "Opened 'Email & app accounts'"
})
Add-ButtonToGrid -btn $btnEmailAppAccounts -row 0 -col 1

$btnFamilyOtherPeople = New-Object System.Windows.Controls.Button
$btnFamilyOtherPeople.Content = "Family & other people"
$btnFamilyOtherPeople.Width = 320
$btnFamilyOtherPeople.Margin = [System.Windows.Thickness]::new(10)
$btnFamilyOtherPeople.Add_Click({
    Start-Process "ms-settings:otherusers"
    Log-Action "Opened 'Family & other people'"
})
Add-ButtonToGrid -btn $btnFamilyOtherPeople -row 1 -col 0

$btnRepairToken = New-Object System.Windows.Controls.Button
$btnRepairToken.Content = "Repair token"
$btnRepairToken.Width = 320
$btnRepairToken.Margin = [System.Windows.Thickness]::new(10)
$btnRepairToken.Add_Click({
    Start-Process "ms-settings:workplace-repairtoken"
    Log-Action "Opened 'Repair token'"
})
Add-ButtonToGrid -btn $btnRepairToken -row 1 -col 1

$btnSetupKiosk = New-Object System.Windows.Controls.Button
$btnSetupKiosk.Content = "Set up a kiosk"
$btnSetupKiosk.Width = 320
$btnSetupKiosk.Margin = [System.Windows.Thickness]::new(10)
$btnSetupKiosk.Add_Click({
    Start-Process "ms-settings:assignedaccess"
    Log-Action "Opened 'Set up a kiosk'"
})
Add-ButtonToGrid -btn $btnSetupKiosk -row 2 -col 0

$btnSigninOptions = New-Object System.Windows.Controls.Button
$btnSigninOptions.Content = "Sign-in options"
$btnSigninOptions.Width = 320
$btnSigninOptions.Margin = [System.Windows.Thickness]::new(10)
$btnSigninOptions.Add_Click({
    Start-Process "ms-settings:signinoptions"
    Log-Action "Opened 'Sign-in options'"
})
Add-ButtonToGrid -btn $btnSigninOptions -row 2 -col 1

$btnSigninOptionsDynamicLock = New-Object System.Windows.Controls.Button
$btnSigninOptionsDynamicLock.Content = "Sign-in options - Dynamic Lock"
$btnSigninOptionsDynamicLock.Width = 320
$btnSigninOptionsDynamicLock.Margin = [System.Windows.Thickness]::new(10)
$btnSigninOptionsDynamicLock.Add_Click({
    Start-Process "ms-settings:signinoptions-dynamiclock"
    Log-Action "Opened 'Dynamic Lock'"
})
Add-ButtonToGrid -btn $btnSigninOptionsDynamicLock -row 3 -col 0

$btnSyncSettings = New-Object System.Windows.Controls.Button
$btnSyncSettings.Content = "Sync your settings"
$btnSyncSettings.Width = 320
$btnSyncSettings.Margin = [System.Windows.Thickness]::new(10)
$btnSyncSettings.Add_Click({
    Start-Process "ms-settings:sync"
    Log-Action "Opened 'Sync your settings'"
})
Add-ButtonToGrid -btn $btnSyncSettings -row 3 -col 1

$btnBackupDeprecated = New-Object System.Windows.Controls.Button
$btnBackupDeprecated.Content = "Windows Backup"
$btnBackupDeprecated.Width = 320
$btnBackupDeprecated.Margin = [System.Windows.Thickness]::new(10)
$btnBackupDeprecated.Add_Click({
    Start-Process "ms-settings:backup"
    Log-Action "Opened 'Backup'"
})
Add-ButtonToGrid -btn $btnBackupDeprecated -row 4 -col 0

$btnWindowsHelloFace = New-Object System.Windows.Controls.Button
$btnWindowsHelloFace.Content = "Windows Hello setup - Face enrollment"
$btnWindowsHelloFace.Width = 320
$btnWindowsHelloFace.Margin = [System.Windows.Thickness]::new(10)
$btnWindowsHelloFace.Add_Click({
    Start-Process "ms-settings:signinoptions-launchfaceenrollment"
    Log-Action "Opened 'Face enrollment'"
})
Add-ButtonToGrid -btn $btnWindowsHelloFace -row 4 -col 1

$btnWindowsHelloFingerprint = New-Object System.Windows.Controls.Button
$btnWindowsHelloFingerprint.Content = "Windows Hello setup - Fingerprint enrollment"
$btnWindowsHelloFingerprint.Width = 320
$btnWindowsHelloFingerprint.Margin = [System.Windows.Thickness]::new(10)
$btnWindowsHelloFingerprint.Add_Click({
    Start-Process "ms-settings:signinoptions-launchfingerprintenrollment"
    Log-Action "Opened 'Fingerprint enrollment'"
})
Add-ButtonToGrid -btn $btnWindowsHelloFingerprint -row 5 -col 0

$btnYourInfo = New-Object System.Windows.Controls.Button
$btnYourInfo.Content = "Your info"
$btnYourInfo.Width = 320
$btnYourInfo.Margin = [System.Windows.Thickness]::new(10)
$btnYourInfo.Add_Click({
    Start-Process "ms-settings:yourinfo"
    Log-Action "Opened 'Your info'"
})
Add-ButtonToGrid -btn $btnYourInfo -row 5 -col 1

# Add to stack panel
$stackPanel.Children.Add($buttonGrid)

# Footer
$textBlockFooter = New-Object System.Windows.Controls.TextBlock
$textBlockFooter.Text = "Allester Padovani, Senior IT Specialist. All rights reserved."
$textBlockFooter.FontSize = 12
$textBlockFooter.FontStyle = [System.Windows.FontStyles]::Italic
$textBlockFooter.Foreground = [System.Windows.Media.Brushes]::Black
$textBlockFooter.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
$textBlockFooter.Margin = [System.Windows.Thickness]::new(0,20,0,5)
$stackPanel.Children.Add($textBlockFooter)

# Show the window
$window.ShowDialog()
