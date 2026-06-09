<#
.SYNOPSIS
    Windows Secure Boot Dashboard with Deployment, CA 2023 Check, and Refresh (PowerShell 5.1+)

.DESCRIPTION
    This script provides a graphical dashboard to display Secure Boot status,
    BIOS mode, system manufacturer, and model. It supports real-time status
    refresh and Windows UEFI CA 2023 certificate verification. Designed primarily
    for HP systems but works on any UEFI-based Windows PC.

    Features:
      - Detects Secure Boot (Enabled/Disabled/Unknown)
      - Detects BIOS mode (UEFI/Legacy)
      - Detects manufacturer and model
      - Provides HP-specific instructions if Secure Boot is disabled
      - Deploys Secure Boot registry trigger for Windows UEFI CA 2023
      - Starts required scheduled tasks for updates
      - Graphical UI with:
         - Deploy button
         - Check CA 2023 certificate button
         - OEM Guidance button
         - Refresh Status button
      - Progress bar and log output
      - Color-coded and descriptive messages

.PARAMETER None
    Run directly from PowerShell 5.1+; no parameters required.

.REQUIREMENTS
    - PowerShell 5.1 or higher
    - Windows 8 or later
    - Administrative privileges recommended
    - Tested on HP ProBook 460 G11 and similar UEFI systems

.NOTES
    Author      : Allester Padovani
    Title       : Microsoft Intune Engineer
    Version     : 1.0
    Date        : 02.02.2026

.EXAMPLE
    PS C:\> .\SecureBootDashboard.ps1
    - Opens a WPF dashboard displaying Secure Boot info, deployment options,
      OEM guidance, and refresh capabilities.

.LINK
    - https://docs.microsoft.com/en-us/windows/security/information-protection/secure-the-boot-process
    - HP ProBook User Guides
#>

# ================================
# POWERSELL STRICT MODE & ERROR PREFERENCE
# ================================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load WPF assemblies for GUI
Add-Type -AssemblyName PresentationFramework

# ================================
# CREATE WINDOW
# ================================
$window = New-Object System.Windows.Window
$window.Title = "Windows Secure Boot Dashboard"
$window.SizeToContent = 'WidthAndHeight'
$window.WindowStartupLocation = 'CenterScreen'
$window.ResizeMode = 'CanMinimize'
$window.Background = 'White'

# ================================
# CREATE MAIN GRID
# ================================
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = '10'

# Define rows (Header, Output, Controls, Footer)
0..5 | ForEach-Object { $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) }

# ================================
# HEADER
# ================================
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Windows Secure Boot – Deployment & CA 2023 Check"
$header.FontSize = 16
$header.FontWeight = 'Bold'
$header.HorizontalAlignment = 'Center'
$header.Margin = '0,0,0,10'
[System.Windows.Controls.Grid]::SetRow($header,0)
$grid.Children.Add($header)

# ================================
# OUTPUT BOX
# ================================
$outputBox = New-Object System.Windows.Controls.TextBox
$outputBox.FontFamily = 'Consolas'
$outputBox.FontSize = 12
$outputBox.IsReadOnly = $true
$outputBox.AcceptsReturn = $true
$outputBox.TextWrapping = 'Wrap'
$outputBox.VerticalScrollBarVisibility = 'Auto'
$outputBox.MinWidth = 600
$outputBox.MinHeight = 300
$outputBox.Text = "Ready..."
[System.Windows.Controls.Grid]::SetRow($outputBox,1)
$grid.Children.Add($outputBox)

# ================================
# CONTROLS PANEL
# ================================
$controls = New-Object System.Windows.Controls.StackPanel
$controls.HorizontalAlignment = 'Center'
$controls.Margin = '10'

# Progress bar
$progress = New-Object System.Windows.Controls.ProgressBar
$progress.Width = 420
$progress.Height = 18
$progress.Maximum = 100
$progress.Margin = '0,0,0,10'
$controls.Children.Add($progress)

# Deploy button
$deployBtn = New-Object System.Windows.Controls.Button
$deployBtn.Content = "Deploy Secure Boot Updates"
$deployBtn.Width = 300
$deployBtn.Margin = '5'
$controls.Children.Add($deployBtn)

# Check CA 2023 certificate button
$checkBtn = New-Object System.Windows.Controls.Button
$checkBtn.Content = "Check Secure Boot CA 2023"
$checkBtn.Width = 300
$checkBtn.Margin = '5'
$controls.Children.Add($checkBtn)

# OEM guidance button
$guidanceBtn = New-Object System.Windows.Controls.Button
$guidanceBtn.Content = "Show Secure Boot OEM Guidance"
$guidanceBtn.Width = 300
$guidanceBtn.Margin = '5'
$controls.Children.Add($guidanceBtn)

# Refresh status button
$refreshBtn = New-Object System.Windows.Controls.Button
$refreshBtn.Content = "Refresh Status"
$refreshBtn.Width = 300
$refreshBtn.Margin = '5'
$controls.Children.Add($refreshBtn)

[System.Windows.Controls.Grid]::SetRow($controls,2)
$grid.Children.Add($controls)

# ================================
# UI HELPER FUNCTIONS
# ================================

# Clears output box and resets progress
function Reset-UI {
    $outputBox.Dispatcher.Invoke([action]{ $outputBox.Clear() })
    $progress.Value = 0
}

# Writes log messages to output box safely from GUI thread
function Write-Log {
    param($msg)
    $outputBox.Dispatcher.Invoke([action]{
        $outputBox.AppendText("$msg`n")
        $outputBox.ScrollToEnd()
    })
}

# ================================
# OEM GUIDANCE
# ================================
function Write-VendorSecureBootGuidance {
    $cs  = Get-CimInstance Win32_ComputerSystem
    $vendor = $cs.Manufacturer.Trim()
    $model  = $cs.Model.Trim()

    try { $sbEnabled = Confirm-SecureBootUEFI; $sbStatus = if ($sbEnabled) { "ENABLED" } else { "DISABLED" } }
    catch { $sbStatus = "UNKNOWN" }

    try { $biosMode = if ($env:firmware_type -eq "UEFI") { "UEFI" } else { "Legacy" } }
    catch { $biosMode = "UNKNOWN" }

    Write-Log "Secure Boot Status : $sbStatus"
    Write-Log "BIOS Mode          : $biosMode"
    Write-Log ""
    Write-Log "Manufacturer : $vendor"
    Write-Log "Model        : $model"
    Write-Log ""

    switch -Regex ($vendor) {
        'Dell' { Write-Log "Dell Secure Boot enablement:`n - Reboot F2 → Boot List = UEFI → Secure Boot Enable" }
        'HP' { Write-Log "HP Secure Boot enablement:`n - Reboot F10 → Boot Options → Secure Boot Enable → Disable Legacy Support" }
        'LENOVO' { Write-Log "Lenovo Secure Boot enablement:`n - Reboot F1/F2 → Security → Secure Boot → Enable → Boot Mode = UEFI" }
        'Microsoft' { Write-Log "Surface Secure Boot enablement:`n - Shut down → Hold Volume Up + Power → Enable Secure Boot Control" }
        default { Write-Log "Generic Secure Boot enablement:`n - Enter UEFI firmware → Set Boot Mode = UEFI → Enable Secure Boot" }
    }

    Write-Log "`nIf Secure Boot is DISABLED, enable it in firmware, then re-run this tool."
}

# ================================
# DEPLOYMENT FUNCTION
# ================================
function Invoke-Deployment {
    $deployBtn.IsEnabled = $false
    Write-Log "Starting deployment..."

    try {
        if (-not (Confirm-SecureBootUEFI)) { throw "Secure Boot OFF" }
        Write-Log "Secure Boot is ENABLED."
    }
    catch {
        Write-Log "ERROR: Secure Boot is OFF."
        Write-Log "Deployment cannot continue."
        Write-Log ""
        Write-VendorSecureBootGuidance
        $deployBtn.IsEnabled = $true
        return
    }

    $progress.Value = 25

    # Registry trigger for Windows UEFI CA 2023
    try {
        $sbKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot"
        if (-not (Test-Path $sbKey)) { New-Item -Path $sbKey -Force | Out-Null }
        Set-ItemProperty -Path $sbKey -Name AvailableUpdates -Value 0x40 -Type DWord
        Write-Log "Registry trigger applied (AvailableUpdates = 0x40)."
    }
    catch { Write-Log "Failed to apply registry trigger: $_" }

    $progress.Value = 50

    # Scheduled task for secure boot update
    $task = Get-ScheduledTask -TaskPath "\Microsoft\Windows\PI\" -TaskName "Secure-Boot-Update" -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Log "ERROR: Secure-Boot-Update task not found."
        Write-Log "Required Windows update (KB5036210+) missing."
        $deployBtn.IsEnabled = $true
        return
    }

    Start-ScheduledTask -InputObject $task
    Write-Log "Secure-Boot-Update scheduled task started."
    $progress.Value = 75

    Write-Log "Deployment staged successfully. Reboot required. Some systems need TWO reboots."
    $progress.Value = 100
    $deployBtn.IsEnabled = $true
}

# ================================
# CHECK SECURE BOOT CA 2023
# ================================
function Check-SecureBootCA2023 {
    $checkBtn.IsEnabled = $false
    Write-Log "Checking Windows UEFI CA 2023 certificate..."

    try {
        if (-not (Confirm-SecureBootUEFI)) { throw "Secure Boot OFF" }
        $db = Get-SecureBootUEFI db
        $text = [System.Text.Encoding]::Unicode.GetString($db.Bytes)

        if ($text -match "Windows UEFI CA 2023") {
            Write-Log "Windows UEFI CA 2023 certificate is PRESENT."
        } else {
            Write-Log "Windows UEFI CA 2023 certificate NOT found. Reboot if deployment was recent."
        }
    }
    catch { Write-Log "Cannot read Secure Boot DB. Secure Boot must be ENABLED." }

    $progress.Value = 100
    $checkBtn.IsEnabled = $true
}

# ================================
# REFRESH STATUS FUNCTION
# ================================
function Refresh-SecureBootStatus {
    Reset-UI
    Write-Log "Refreshing system status..."

    $cs  = Get-CimInstance Win32_ComputerSystem
    $vendor = $cs.Manufacturer.Trim()
    $model  = $cs.Model.Trim()

    try { $sbEnabled = Confirm-SecureBootUEFI; $sbStatus = if ($sbEnabled) { "ENABLED" } else { "DISABLED" } }
    catch { $sbStatus = "UNKNOWN" }

    try { $biosMode = if ($env:firmware_type -eq "UEFI") { "UEFI" } else { "Legacy" } }
    catch { $biosMode = "UNKNOWN" }

    Write-Log "Secure Boot Status : $sbStatus"
    Write-Log "BIOS Mode          : $biosMode"
    Write-Log ""
    Write-Log "Manufacturer : $vendor"
    Write-Log "Model        : $model"
    Write-Log ""

    # Check Windows UEFI CA 2023 certificate presence
    try {
        if ($sbEnabled) {
            $db = Get-SecureBootUEFI db
            $text = [System.Text.Encoding]::Unicode.GetString($db.Bytes)
            if ($text -match "Windows UEFI CA 2023") {
                Write-Log "Windows UEFI CA 2023 certificate is PRESENT."
            } else {
                Write-Log "Windows UEFI CA 2023 certificate NOT found. Reboot if deployment was recent."
            }
        } else {
            Write-Log "Secure Boot is DISABLED. Certificate check skipped."
        }
    }
    catch { Write-Log "Unable to read Secure Boot DB." }

    $progress.Value = 100
    Write-Log "Status refresh complete."
}

# ================================
# BUTTON EVENTS
# ================================
$deployBtn.Add_Click({ Reset-UI; Invoke-Deployment })
$checkBtn.Add_Click({ Reset-UI; Check-SecureBootCA2023 })
$guidanceBtn.Add_Click({ Reset-UI; Write-VendorSecureBootGuidance })
$refreshBtn.Add_Click({ Refresh-SecureBootStatus })

# ================================
# FOOTER
# ================================
$footer = New-Object System.Windows.Controls.Label
$footer.Content = "© 2026 Allester Padovani | Microsoft Intune Engineer"
$footer.HorizontalAlignment = 'Center'
$footer.Margin = '0,10,0,0'
[System.Windows.Controls.Grid]::SetRow($footer,5)
$grid.Children.Add($footer)

# ================================
# SHOW WINDOW
# ================================
$window.Content = $grid
$window.ShowDialog() | Out-Null
