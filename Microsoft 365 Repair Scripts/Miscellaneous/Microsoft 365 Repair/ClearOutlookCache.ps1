<#
.SYNOPSIS
    Outlook cleanup tool for Microsoft 365 users only.

.DESCRIPTION
    - Blocks execution if PST files are detected
    - Requires user confirmation that:
        • Mailbox is M365 (Exchange Online)
        • Issue is Outlook-related
    - Clears Outlook cache and roaming profile safely
    - Fully GUI-based; hides PowerShell console

.AUTHOR
    Name        : Allester Padovani
    Title       : Microsoft Intune Engineer
    Script Ver. : 1.0
    Date        : 2026-01-18
#>

# ================== INITIAL SETUP ==================
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# ================== ADMIN CHECK ==================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb      = "runas"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}

# ================== HIDE CONSOLE ==================
$consolePtr = (Get-Process -Id $PID).MainWindowHandle
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
"@
[Win32]::ShowWindowAsync($consolePtr, 0)  # SW_HIDE

# ================== SAFETY CHECK — PST Detection ==================
$pstLocations = @(
    "$env:USERPROFILE\Documents\Outlook Files",
    "$env:APPDATA\Microsoft\Outlook"
)

$pstFiles = foreach ($path in $pstLocations) {
    if (Test-Path $path) {
        Get-ChildItem $path -Filter *.pst -Recurse -ErrorAction SilentlyContinue
    }
}

if ($pstFiles) {
    [System.Windows.Forms.MessageBox]::Show(
        "PST files were detected on this system.

This script MUST NOT be used when:
• Local-only PST mailboxes exist
• Archive PSTs are in use

Cleanup has been BLOCKED to prevent data loss.",
        "PST Files Detected",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

# ================== USER CONFIRMATION ==================
$confirmation = [System.Windows.Forms.MessageBox]::Show(
@"
Before continuing, confirm ALL of the following:

✔ User mailbox is Microsoft 365 (Exchange Online)
✔ No PST files are used
✔ Issue is Outlook-related (not MFA, CA, licensing, or network)
✔ Outlook may be reset and must be signed in again

Click YES to proceed or NO to cancel.
"@,
"Outlook Cleanup Confirmation",
[System.Windows.Forms.MessageBoxButtons]::YesNo,
[System.Windows.Forms.MessageBoxIcon]::Warning
)

if ($confirmation -ne [System.Windows.Forms.DialogResult]::Yes) {
    exit
}

# ================== WPF WINDOW ==================
$window = New-Object System.Windows.Window
$window.Title = "Outlook Cache Cleaner (M365 Only)"
$window.SizeToContent = "WidthAndHeight"
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "NoResize"
$window.Background = "#f4f4f4"

# --- GRID Layout ---
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = 15
for ($i=0; $i -lt 4; $i++) { $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) }

# --- HEADER ---
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Outlook Cleanup Tool (M365)"
$header.FontSize = 16
$header.FontWeight = "Bold"
$header.HorizontalAlignment = "Center"
$header.Margin = "0,0,0,15"
[System.Windows.Controls.Grid]::SetRow($header, 0)
$grid.Children.Add($header)

# --- BUTTON PANEL ---
$buttonPanel = New-Object System.Windows.Controls.StackPanel
$buttonPanel.HorizontalAlignment = "Center"
$startButton = New-Object System.Windows.Controls.Button
$startButton.Content = "Start Cleanup"
$startButton.Width = 260
$startButton.Margin = 5
$startButton.FontWeight = "Bold"
$buttonPanel.Children.Add($startButton) | Out-Null
[System.Windows.Controls.Grid]::SetRow($buttonPanel, 1)
$grid.Children.Add($buttonPanel)

# --- STATUS / PROGRESS BAR PANEL ---
$statusPanel = New-Object System.Windows.Controls.StackPanel
$statusPanel.HorizontalAlignment = "Center"
$progressBar = New-Object System.Windows.Controls.ProgressBar
$progressBar.Width = 350; $progressBar.Height = 20; $progressBar.Minimum = 0; $progressBar.Maximum = 100; $progressBar.Value = 0; $progressBar.Margin = "0,0,0,10"
$statusText = New-Object System.Windows.Controls.TextBlock
$statusText.Text = "Ready."; $statusText.HorizontalAlignment = "Center"
$warningText = New-Object System.Windows.Controls.TextBlock
$warningText.Text = "DO NOT USE for PST, POP/IMAP, or non-M365 mailboxes."
$warningText.FontStyle = "Italic"; $warningText.Foreground = [System.Windows.Media.Brushes]::DarkRed; $warningText.TextAlignment = "Center"
$statusPanel.Children.Add($progressBar) | Out-Null
$statusPanel.Children.Add($statusText)   | Out-Null
$statusPanel.Children.Add($warningText)  | Out-Null
[System.Windows.Controls.Grid]::SetRow($statusPanel, 2)
$grid.Children.Add($statusPanel)

# --- FOOTER PANEL ---
$footerPanel = New-Object System.Windows.Controls.StackPanel
$footerPanel.HorizontalAlignment = "Center"; $footerPanel.Margin = "0,10,0,0"
$copyrightTextBlock = New-Object System.Windows.Controls.Label
$copyrightTextBlock.Content = "Copyright " + [char]169 + " 2026 Allester Padovani | Microsoft Intune Engineer"
$copyrightTextBlock.FontFamily = 'Segoe UI'; $copyrightTextBlock.FontSize = 11
$footerPanel.Children.Add($copyrightTextBlock) | Out-Null
[System.Windows.Controls.Grid]::SetRow($footerPanel, 3)
$grid.Children.Add($footerPanel)

# ================== HELPER FUNCTIONS ==================
function Update-Progress {
    param([int]$Value, [string]$Text)
    $progressBar.Value = $Value
    $statusText.Text   = $Text
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 600
}

function Kill-OutlookProcesses {
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match "outlook" } |
        ForEach-Object {
            try { Stop-Process -Id $_.Id -Force } catch {}
        }
}

function Clear-OutlookLocalCache {
    $path = "$env:LOCALAPPDATA\Microsoft\Outlook"
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Clear-OutlookRoamingM365 {
    $path = "$env:APPDATA\Microsoft\Outlook"
    if (Test-Path $path) {
        Get-ChildItem $path -Force | ForEach-Object {
            if ($_.Extension -ne ".pst") {
                Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# ================== BUTTON CLICK ==================
$startButton.Add_Click({
    $startButton.IsEnabled = $false
    Update-Progress 10  "Closing Outlook..."
    Kill-OutlookProcesses

    Update-Progress 40  "Clearing local cache..."
    Clear-OutlookLocalCache

    Update-Progress 70  "Resetting Outlook profile..."
    Clear-OutlookRoamingM365

    Update-Progress 100 "Cleanup completed."

    [System.Windows.Forms.MessageBox]::Show(
        "Outlook cleanup completed successfully.`n`nPlease open Outlook and sign in again.",
        "Completed",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    $startButton.IsEnabled = $true
})

# ================== SHOW WINDOW ==================
$window.Content = $grid
$window.ShowDialog() | Out-Null
exit
