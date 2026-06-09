<#
.SYNOPSIS
    WPF GUI to terminate Microsoft Teams and clean its cache folders.

.DESCRIPTION
    Provides a WPF-based GUI interface that terminates all Microsoft Teams processes and deletes both local and roaming cache folders.
    Displays real-time progress via a WPF progress bar and confirms completion using a Windows Forms message box.

.AUTHOR
    Name        : Allester Padovani
    Title       : Microsoft Intune Engineer
    Script Ver. : 1.0
    Date        : 2025-07-20

.NOTES
    Technologies:
        - WPF (inline XAML)
        - System.Windows.Forms for DoEvents and MessageBox
        - PresentationFramework.dll for WPF rendering
        - Compatible with Windows 11 24H2 and later
#>

# ================== INITIAL SETUP ==================
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# ================== ADMIN CHECK ==================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb      = "runas"  # triggers admin UAC
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
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

# ================== WPF WINDOW ==================
$window = New-Object System.Windows.Window
$window.Title = "Microsoft Teams Cache Cleaner"
$window.SizeToContent = "WidthAndHeight"
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "NoResize"
$window.Background = "#f4f4f4"

# --- GRID Layout ---
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = 15
for ($i = 0; $i -lt 4; $i++) { $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) }

# --- HEADER ---
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Microsoft Teams Cache Cleaner"
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
$warningText.Text = "DO NOT USE for non-Teams or non-Windows 11 systems."
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

function Kill-TeamsProcesses {
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -like "*teams*" } |
        ForEach-Object {
            try { Stop-Process -Id $_.Id -Force } catch {}
        }
}

function Clear-TeamsCache {
    $paths = @(
        "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe",
        "$env:APPDATA\Microsoft\Teams"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ================== BUTTON CLICK ==================
$startButton.Add_Click({
    $startButton.IsEnabled = $false
    Update-Progress 10  "Terminating Teams processes..."
    Kill-TeamsProcesses

    Update-Progress 40  "Removing Teams cache folders..."
    Clear-TeamsCache

    Update-Progress 100 "Cleanup completed."

    [System.Windows.Forms.MessageBox]::Show(
        "Microsoft Teams cache and temporary files have been removed.",
        "Cleanup Complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    $startButton.IsEnabled = $true
})

# ================== SHOW WINDOW ==================
$window.Content = $grid
$window.ShowDialog() | Out-Null
exit
