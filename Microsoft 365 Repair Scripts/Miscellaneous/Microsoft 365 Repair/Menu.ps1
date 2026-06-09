<#
.DESCRIPTION
    Office 365 Cache & Credential Dashboard (GUI)

.AUTHOR
    Name        : Allester Padovani
    Title       : Microsoft Intune Engineer
    Script Ver. : 1.0
    Date        : 2026-01-22
#>

# ================== INITIAL SETUP ==================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# ================== GLOBAL STATE ==================
$script:InstructionsViewed = $false

# ================== HELPER FUNCTIONS ==================
function Do-Events { [System.Windows.Forms.Application]::DoEvents() }

function Enable-ActionButtons {
    if ($script:InstructionsViewed) {
        $btnOutlook.IsEnabled = $true
        $btnTeams.IsEnabled  = $true
        $btnCreds.IsEnabled  = $true
    }
}

# Determine script folder
if ($PSCommandPath) {
    $ScriptFolder = Split-Path -Parent $PSCommandPath
} else {
    $ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

function Launch-Script {
    param (
        [string]$ScriptPath,
        [string]$ActionName
    )

    if (-not (Test-Path $ScriptPath)) {
        [System.Windows.MessageBox]::Show(
            "Script not found:`n$ScriptPath",
            "Error",
            "OK",
            "Error"
        ) | Out-Null
        return
    }

    $txtStatus.Text = "Launching $ActionName..."
    $progressBar.Value = 50
    Do-Events

    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" `
        -Verb RunAs

    $txtStatus.Text = "$ActionName launched."
    $progressBar.Value = 100
    Start-Sleep -Milliseconds 500
    $progressBar.Value = 0
    $txtStatus.Text = "Ready"
}

# ================== INSTRUCTIONS WINDOW ==================
function Show-InstructionsGUI {

$instructions = @"
HOW IT WORKS:

1. Clear Outlook Cache:
   Removes OST files, profiles, and temporary Outlook files that may cause
   sync or startup issues. These cached files allow quick access to emails
   and calendar data. Clearing them resolves slow syncing, errors, and
   Outlook startup delays.

2. Clear Teams Cache:
   Terminates Microsoft Teams processes and deletes cache folders that store
   temporary files, cookies, and chat data. Corrupted cache can cause issues
   loading chats, meetings, or Teams features. This resets Teams for smoother
   performance.

3. Open Credential Manager:
   Opens Windows Credential Manager to manage saved Office credentials.
   Removing stored credentials can fix authentication and sign-in issues.

DATA SAFETY:
- NO important data is lost.
- ONLY temporary cache files and credentials are affected.
- Emails, Teams chats, and OneDrive files remain safe.
- User preferences and open work are not modified.

USER NOTES:
- You may need to sign back into Outlook and Teams.
- Administrator rights are required.

IF ISSUES CONTINUE:
1. Retry the cleanup process.
2. Delete Outlook profiles:
   Control Panel > Mail (Microsoft Outlook) > Show Profiles > Remove.
3. Last resort:
   Microsoft 365 Offline Repair:
   Settings > Apps > Installed Apps >
   Microsoft 365 Apps for Business > Modify > Offline Repair.

After completing these steps, most Office 365 performance and
connectivity issues should be resolved.
"@

    $w = New-Object System.Windows.Window
    $w.Title = "Instructions / How It Works (Required)"
    $w.Width = 700
    $w.Height = 800
    $w.MinWidth = 650
    $w.MinHeight = 600
    $w.WindowStartupLocation = "CenterScreen"
    $w.ResizeMode = "CanResize"
    $w.Background = "#f4f4f4"
    $w.Owner = $window
    $w.Topmost = $true

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = 15

    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.RowDefinitions[0].Height = "*"
    $grid.RowDefinitions[1].Height = "Auto"

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $instructions
    $text.TextWrapping = "Wrap"
    $text.FontFamily = "Segoe UI"
    $text.FontSize = 13
    $text.Margin = "0,0,0,10"

    $scroll.Content = $text
    [System.Windows.Controls.Grid]::SetRow($scroll, 0)

    $ackBtn = New-Object System.Windows.Controls.Button
    $ackBtn.Content = "I Have Read and Understand"
    $ackBtn.Width = 300
    $ackBtn.HorizontalAlignment = "Center"
    $ackBtn.Margin = "0,10,0,0"
    $ackBtn.Add_Click({
        $script:InstructionsViewed = $true
        Enable-ActionButtons
        $w.Close()
    })

    [System.Windows.Controls.Grid]::SetRow($ackBtn, 1)

    $grid.Children.Add($scroll) | Out-Null
    $grid.Children.Add($ackBtn) | Out-Null

    $w.Content = $grid
    $w.ShowDialog() | Out-Null
}

# ================== CREATE MAIN WINDOW ==================
$window = New-Object System.Windows.Window
$window.Title = "Office 365 Cache & Credential Dashboard"
$window.SizeToContent = "WidthAndHeight"
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "NoResize"
$window.Background = "#f4f4f4"

# ================== GRID ==================
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = 15
for ($i=0; $i -lt 4; $i++) {
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
}

# ================== HEADER ==================
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Office 365 Cache & Credential Dashboard"
$header.FontSize = 16
$header.FontWeight = "Bold"
$header.Margin = "0,0,0,15"
$header.HorizontalAlignment = "Center"
[System.Windows.Controls.Grid]::SetRow($header, 0)
$grid.Children.Add($header)

# ================== BUTTON PANEL ==================
$buttonPanel = New-Object System.Windows.Controls.StackPanel
$buttonPanel.HorizontalAlignment = "Center"
$buttonPanel.Margin = "0,0,0,15"

$buttonWidth = 260
$buttonMargin = 5

$btnOutlook = New-Object System.Windows.Controls.Button
$btnOutlook.Content = "Clear Outlook Cache"
$btnOutlook.Width = $buttonWidth
$btnOutlook.Margin = $buttonMargin
$btnOutlook.IsEnabled = $false

$btnTeams = New-Object System.Windows.Controls.Button
$btnTeams.Content = "Clear Teams Cache"
$btnTeams.Width = $buttonWidth
$btnTeams.Margin = $buttonMargin
$btnTeams.IsEnabled = $false

$btnCreds = New-Object System.Windows.Controls.Button
$btnCreds.Content = "Open Credential Manager"
$btnCreds.Width = $buttonWidth
$btnCreds.Margin = $buttonMargin
$btnCreds.IsEnabled = $false

$btnInstructions = New-Object System.Windows.Controls.Button
$btnInstructions.Content = "Instructions / How It Works (Required)"
$btnInstructions.Width = $buttonWidth
$btnInstructions.Margin = $buttonMargin
$btnInstructions.Add_Click({ Show-InstructionsGUI })

$buttonPanel.Children.Add($btnOutlook)      | Out-Null
$buttonPanel.Children.Add($btnTeams)        | Out-Null
$buttonPanel.Children.Add($btnCreds)        | Out-Null
$buttonPanel.Children.Add($btnInstructions) | Out-Null

[System.Windows.Controls.Grid]::SetRow($buttonPanel, 1)
$grid.Children.Add($buttonPanel)

# ================== STATUS ==================
$statusPanel = New-Object System.Windows.Controls.StackPanel
$statusPanel.HorizontalAlignment = "Center"
$statusPanel.Margin = "0,0,0,15"

$progressBar = New-Object System.Windows.Controls.ProgressBar
$progressBar.Width = 350
$progressBar.Height = 20
$progressBar.Maximum = 100
$progressBar.Margin = "0,0,0,10"

$txtStatus = New-Object System.Windows.Controls.TextBlock
$txtStatus.Text = "Ready"
$txtStatus.HorizontalAlignment = "Center"

$statusPanel.Children.Add($progressBar) | Out-Null
$statusPanel.Children.Add($txtStatus)   | Out-Null
[System.Windows.Controls.Grid]::SetRow($statusPanel, 2)
$grid.Children.Add($statusPanel)

# ================== FOOTER ==================
$footer = New-Object System.Windows.Controls.Label
$footer.Content = "Copyright © 2026 Allester Padovani | Microsoft Intune Engineer"
$footer.FontSize = 11
$footer.HorizontalAlignment = "Center"
[System.Windows.Controls.Grid]::SetRow($footer, 3)
$grid.Children.Add($footer)

# ================== BUTTON EVENTS ==================
$btnOutlook.Add_Click({
    Launch-Script "$ScriptFolder\ClearOutlookCache.ps1" "Clear Outlook Cache"
})
$btnTeams.Add_Click({
    Launch-Script "$ScriptFolder\ClearTeamsCache.ps1" "Clear Teams Cache"
})
$btnCreds.Add_Click({
    Start-Process "control.exe" -ArgumentList "/name Microsoft.CredentialManager"
})

# ================== SHOW ==================
$window.Content = $grid
$window.ShowDialog() | Out-Null
exit
