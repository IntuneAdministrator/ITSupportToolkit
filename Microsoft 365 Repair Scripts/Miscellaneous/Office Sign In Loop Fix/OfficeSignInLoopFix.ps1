<#
.SYNOPSIS
    Office Sign-In Loop Fix Dashboard (GUI)

.DESCRIPTION
    Displays Office Modern Authentication (ADAL/WAM) status and allows one-click remediation.
    Fixes repeated Office sign-in prompts caused by Modern Authentication being disabled.

    Intune-safe: Per-user registry changes only (HKCU).
    No admin rights required.
    Users must read instructions before using buttons.

.AUTHOR
    Name        : Allester Padovani
    Title       : Microsoft Intune Engineer
    Script Ver. : 1.0
    Date        : 01.26.2026
#>

# ================== INITIAL SETUP ==================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

$IdentityRegPath = "HKCU:\Software\Microsoft\Office\16.0\Common\Identity"

# ================== GLOBAL STATE ==================
$script:InstructionsViewed = $false

# ================== INSTRUCTIONS TEXT ==================
$instructions = @"
HOW IT WORKS:

1. View and acknowledge these instructions (required)
2. Review your current Office authentication status.
3. Click 'Fix Sign-In Loop (Recommended)' if Modern Authentication is disabled.
4. Restart all Office apps after applying the fix.
5. Optional: View Office Identity Registry to verify changes.

WHAT THE SCRIPT DOES:

- Enables Modern Authentication (ADAL) in Office.
- Enables WAM integration for SSO.
- Fixes repeated Office sign-in prompts (sign-in loop).

DATA SAFETY (IMPORTANT):

- Only user-specific registry keys (HKCU) are modified.
- No admin rights required.
- No Office data, files, or emails are deleted or modified.
"@

# ================== LOGGING FUNCTION ==================
function Log-Action {
    param ([string]$Message)
    $logName = "Application"
    $source  = "PowerShell - Office Sign-In Fix"
    if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
        try { New-EventLog -LogName $logName -Source $source } catch {}
    }
    Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 2001 -Message $Message
}

# ================== HELPER FUNCTIONS ==================
function Get-OfficeAuthStatus {
    if (-not (Test-Path $IdentityRegPath)) {
        return [PSCustomObject]@{
            EnableADAL = "Not Set"
            WAM        = "Not Set"
            Status     = "Office Identity key missing"
        }
    }
    $props = Get-ItemProperty -Path $IdentityRegPath -ErrorAction SilentlyContinue

    $adal = if ($props.PSObject.Properties.Name -contains "EnableADAL") { $props.EnableADAL } else { "Not Set" }
    $wam  = if ($props.PSObject.Properties.Name -contains "DisableADALatopWAM") {
                if ($props.DisableADALatopWAM -eq 0) { "Enabled" } elseif ($props.DisableADALatopWAM -eq 1) { "Disabled" } else { "Not Set" }
            } else { "Not Set" }

    $status = if ($adal -eq 1) { "Modern Authentication Enabled" } else { "Modern Authentication Disabled (Sign-in Loop Risk)" }

    return [PSCustomObject]@{ EnableADAL = $adal; WAM = $wam; Status = $status }
}

function Fix-OfficeSignInLoop {
    if (-not (Test-Path $IdentityRegPath)) { New-Item -Path $IdentityRegPath -Force | Out-Null }
    Set-ItemProperty -Path $IdentityRegPath -Name EnableADAL -Value 1 -Type DWord
    Set-ItemProperty -Path $IdentityRegPath -Name DisableADALatopWAM -Value 0 -Type DWord
    Log-Action "Enabled Office Modern Authentication (EnableADAL=1, WAM enabled)."

    [System.Windows.MessageBox]::Show(
        "Fix applied successfully.`nPlease restart all Office apps.",
        "Office Sign-In Loop Fixed",
        "OK",
        "Information"
    )
    Refresh-Status
}

function Open-IdentityRegistry {
    if (Test-Path $IdentityRegPath) {
        Start-Process "regedit.exe" "/m $IdentityRegPath"
    } else {
        [System.Windows.MessageBox]::Show(
            "Registry path not found: $IdentityRegPath",
            "Registry Not Found",
            "OK",
            "Warning"
        )
    }
}

function Restart-ComputerPrompt {
    $result = [System.Windows.MessageBox]::Show(
        "Are you sure you want to restart the computer? Please save everything before clicking OK.",
        "Restart Confirmation",
        "OKCancel",
        "Warning"
    )

    if ($result -eq "OK") {
        [System.Windows.MessageBox]::Show(
            "The computer will restart in 1 minute.",
            "Restart Scheduled",
            "OK",
            "Information"
        )
        shutdown.exe /r /t 60
    }
}

# ================== INSTRUCTIONS GUI ==================
function Show-InstructionsGUI {
    $w = New-Object System.Windows.Window
    $w.Title = "Script Instructions (Required)"
    $w.SizeToContent = "WidthAndHeight"
    $w.WindowStartupLocation = "CenterScreen"
    $w.ResizeMode = "NoResize"

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = 20

    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = "Please review before proceeding"
    $header.FontSize = 16
    $header.FontWeight = "Bold"
    $header.HorizontalAlignment = "Center"
    $header.Margin = "0,0,0,10"

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $instructions
    $text.Width = 450
    $text.TextWrapping = "Wrap"
    $text.Margin = "0,0,0,15"

    $ackBtn = New-Object System.Windows.Controls.Button
    $ackBtn.Content = "I Have Read and Understand"
    $ackBtn.Width = 260
    $ackBtn.HorizontalAlignment = "Center"
    $ackBtn.Add_Click({
        $script:InstructionsViewed = $true
        $fixBtn.IsEnabled = $true
        $refreshBtn.IsEnabled = $true
        $viewRegistryBtn.IsEnabled = $true
        $restartBtn.IsEnabled = $true
        $w.Close()
    })

    $stack.Children.Add($header) | Out-Null
    $stack.Children.Add($text)   | Out-Null
    $stack.Children.Add($ackBtn) | Out-Null

    $w.Content = $stack
    $w.ShowDialog() | Out-Null
}

# ================== MAIN GUI ==================
$window = New-Object System.Windows.Window
$window.Title = "Office Sign-In Loop Fix Dashboard"
$window.SizeToContent = "WidthAndHeight"
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "NoResize"

$mainGrid = New-Object System.Windows.Controls.Grid
$mainGrid.Margin = 20

# Define rows: Header, Status, Buttons, Footer
$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Header
$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Status
$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Buttons
$mainGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Footer

# ------------------ Header ------------------
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Office Sign-In Loop Fix"
$header.FontSize = 18
$header.FontWeight = "Bold"
$header.HorizontalAlignment = "Center"
$header.Margin = "0,0,0,10"
[System.Windows.Controls.Grid]::SetRow($header, 0)
$mainGrid.Children.Add($header)

# ------------------ Status Panel ------------------
$status = Get-OfficeAuthStatus

$adalText   = New-Object System.Windows.Controls.TextBlock
$wamText    = New-Object System.Windows.Controls.TextBlock
$statusText = New-Object System.Windows.Controls.TextBlock
$statusText.FontWeight = "Bold"

$adalText.Text   = "EnableADAL: $($status.EnableADAL)"
$wamText.Text    = "WAM Status: $($status.WAM)"
$statusText.Text = "Overall Status: $($status.Status)"

$statusPanel = New-Object System.Windows.Controls.StackPanel
$statusPanel.Children.Add($adalText)   | Out-Null
$statusPanel.Children.Add($wamText)    | Out-Null
$statusPanel.Children.Add($statusText) | Out-Null
$statusPanel.Margin = "0,0,0,15"

[System.Windows.Controls.Grid]::SetRow($statusPanel, 1)
$mainGrid.Children.Add($statusPanel)

function Refresh-Status {
    $s = Get-OfficeAuthStatus
    $adalText.Text   = "EnableADAL: $($s.EnableADAL)"
    $wamText.Text    = "WAM Status: $($s.WAM)"
    $statusText.Text = "Overall Status: $($s.Status)"
}

# ------------------ Buttons ------------------
$buttonPanel = New-Object System.Windows.Controls.StackPanel
$buttonPanel.Orientation = "Vertical"
$buttonPanel.HorizontalAlignment = "Center"
$buttonPanel.Margin = "0,0,0,15"

$viewInstrBtn = New-Object System.Windows.Controls.Button
$viewInstrBtn.Content = "View Script Instructions (Required)"
$viewInstrBtn.Width = 260
$viewInstrBtn.Margin = "0,0,0,10"
$viewInstrBtn.Add_Click({ Show-InstructionsGUI })

$fixBtn = New-Object System.Windows.Controls.Button
$fixBtn.Content = "Fix Sign-In Loop (Recommended)"
$fixBtn.Width = 260
$fixBtn.Margin = "0,0,0,10"
$fixBtn.IsEnabled = $false
$fixBtn.Add_Click({ Fix-OfficeSignInLoop })

$refreshBtn = New-Object System.Windows.Controls.Button
$refreshBtn.Content = "Refresh Status"
$refreshBtn.Width = 260
$refreshBtn.Margin = "0,0,0,10"
$refreshBtn.IsEnabled = $false
$refreshBtn.Add_Click({ Refresh-Status })

$viewRegistryBtn = New-Object System.Windows.Controls.Button
$viewRegistryBtn.Content = "View Office Identity Registry"
$viewRegistryBtn.Width = 260
$viewRegistryBtn.Margin = "0,0,0,10"
$viewRegistryBtn.IsEnabled = $false
$viewRegistryBtn.Add_Click({ Open-IdentityRegistry })

$restartBtn = New-Object System.Windows.Controls.Button
$restartBtn.Content = "Restart Computer (1 min)"
$restartBtn.Width = 260
$restartBtn.Margin = "0,0,0,10"
$restartBtn.IsEnabled = $false
$restartBtn.Add_Click({ Restart-ComputerPrompt })

$buttonPanel.Children.Add($viewInstrBtn) | Out-Null
$buttonPanel.Children.Add($fixBtn)       | Out-Null
$buttonPanel.Children.Add($refreshBtn)   | Out-Null
$buttonPanel.Children.Add($viewRegistryBtn) | Out-Null
$buttonPanel.Children.Add($restartBtn)   | Out-Null

[System.Windows.Controls.Grid]::SetRow($buttonPanel, 2)
$mainGrid.Children.Add($buttonPanel)

# ------------------ Footer ------------------
$footerPanel = New-Object System.Windows.Controls.Grid
$footerPanel.Margin = [System.Windows.Thickness]::new(10)
$footerPanel.HorizontalAlignment = 'Stretch'
$footerPanel.VerticalAlignment = 'Bottom'
$footerPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) # Column 1
$footerPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) # Column 2
$footerPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) # Column 3

# Copyright
$copyrightTextBlock = New-Object System.Windows.Controls.Label
$copyrightTextBlock.Content = "Copyright " + [char]169 + " 2026 Allester Padovani | Microsoft Intune Engineer"
$copyrightTextBlock.FontFamily = 'Segoe UI'
$copyrightTextBlock.HorizontalAlignment = 'Left'
$copyrightTextBlock.VerticalAlignment = 'Center'
[System.Windows.Controls.Grid]::SetColumn($copyrightTextBlock, 0)
$footerPanel.Children.Add($copyrightTextBlock)

[System.Windows.Controls.Grid]::SetRow($footerPanel, 3)
$mainGrid.Children.Add($footerPanel)

# ------------------ Show Window ------------------
$window.Content = $mainGrid
$window.ShowDialog() | Out-Null
