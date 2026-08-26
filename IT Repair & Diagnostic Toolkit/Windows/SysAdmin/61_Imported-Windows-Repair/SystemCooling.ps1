<#
.SYNOPSIS
    System Cooling Policy Dashboard GUI.

.DESCRIPTION
    Provides a modern WPF GUI to manage Windows System Cooling Policy
    and Power Plan settings. Allows enabling/disabling hidden cooling
    options, checking system type (Laptop/Desktop), and applying
    recommended AC/DC power configurations.

    Displays real-time system diagnostics including CPU load,
    power plan status, battery state, and cooling policy support.

    Designed for IT administrators, Intune deployments, and
    system optimization troubleshooting.

.AUTHOR
    Name        : Allester Padovani
    Title       : Microsoft Intune Engineer
    Script Ver. : 1.0
    Date        : 01.28.2026

.NOTES
    Requires Administrator privileges
    Compatible with Windows 10 / Windows
    Uses PowerShell WPF (PresentationFramework)
    https://www.top-password.com/blog/fix-system-cooling-policy-missing-in-power-options/
    https://www.4winkey.com/windows-10/how-to-activate-or-deactivate-system-cooling-policy-in-windows-10
#>

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# =========================
# AUTO ADMIN ELEVATION
# =========================

$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process powershell.exe -Verb RunAs -ArgumentList (
        "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    )

    exit
}

# =========================
# REGISTRY PATH
# =========================

$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\94D3A615-A899-4AC5-AE2B-E4D8F634367F"

$SubGroup = "54533251-82be-4824-96c1-47b60b740d00"
$Setting  = "94D3A615-A899-4AC5-AE2B-E4D8F634367F"

# =========================
# SYSTEM DETECTION (FIXED)
# =========================

function Get-SystemType {

    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue

        if ($battery) {
            return "Laptop"
        }

        $chassis = Get-CimInstance Win32_SystemEnclosure
        if ($chassis.ChassisTypes -contains 9 -or
            $chassis.ChassisTypes -contains 10 -or
            $chassis.ChassisTypes -contains 14) {
            return "Laptop"
        }

        return "Desktop"
    }
    catch {
        return "Unknown"
    }
}

# =========================
# COOLING SUPPORT CHECK (FIXED)
# =========================

function Test-CoolingSupport {

    try {
        $result = powercfg /q SCHEME_CURRENT SUB_PROCESSOR 2>$null

        if ($result -match "SYSTEMCOOLINGPOLICY") {
            return $true
        }

        return $false
    }
    catch {
        return $false
    }
}

# =========================
# POWER CONTROL
# =========================

function Set-Cooling($mode) {

    switch ($mode) {
        "AC_Active"  { powercfg /setacvalueindex SCHEME_CURRENT $SubGroup $Setting 0 }
        "AC_Passive" { powercfg /setacvalueindex SCHEME_CURRENT $SubGroup $Setting 1 }
        "DC_Active"  { powercfg /setdcvalueindex SCHEME_CURRENT $SubGroup $Setting 0 }
        "DC_Passive" { powercfg /setdcvalueindex SCHEME_CURRENT $SubGroup $Setting 1 }
    }

    powercfg /setactive SCHEME_CURRENT
}

# =========================
# WINDOW
# =========================

$window = New-Object System.Windows.Window
$window.Title = "System Cooling Policy Control Center"
$window.Width = 540
$window.Height = 580
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "NoResize"
$window.Background = "White"

# =========================
# GRID
# =========================

$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = "10"

$row1 = New-Object System.Windows.Controls.RowDefinition
$row1.Height = "Auto"

$row2 = New-Object System.Windows.Controls.RowDefinition
$row2.Height = "*"

$row3 = New-Object System.Windows.Controls.RowDefinition
$row3.Height = "Auto"

$grid.RowDefinitions.Add($row1)
$grid.RowDefinitions.Add($row2)
$grid.RowDefinitions.Add($row3)

# =========================
# HEADER
# =========================

$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "System Cooling Policy Control Center"
$header.FontSize = 18
$header.FontWeight = "Bold"
$header.HorizontalAlignment = "Center"
$header.Margin = "0,0,0,5"

[System.Windows.Controls.Grid]::SetRow($header,0)
$grid.Children.Add($header)

# =========================
# OUTPUT BOX
# =========================

$output = New-Object System.Windows.Controls.TextBox
$output.FontFamily = "Consolas"
$output.FontSize = 12
$output.IsReadOnly = $true
$output.TextWrapping = "Wrap"
$output.VerticalScrollBarVisibility = "Auto"
$output.HorizontalScrollBarVisibility = "Auto"
$output.Text = "Ready..."

[System.Windows.Controls.Grid]::SetRow($output,1)
$grid.Children.Add($output)

# =========================
# BUTTON GRID
# =========================

$btnGrid = New-Object System.Windows.Controls.Grid
$btnGrid.Margin = "5"

1..2 | ForEach-Object { $btnGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) }
1..3 | ForEach-Object { $btnGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) }

function New-Button($text){
    $b = New-Object System.Windows.Controls.Button
    $b.Content = $text
    $b.Height = 40
    $b.Margin = "5"
    return $b
}

$showBtn   = New-Button "Show Policy"
$hideBtn   = New-Button "Hide Policy"
$statusBtn = New-Button "Check Status"
$applyBtn  = New-Button "Apply Recommended"
$powerBtn  = New-Button "Power Options"
$exitBtn   = New-Button "Exit"

[System.Windows.Controls.Grid]::SetRow($showBtn,0);   [System.Windows.Controls.Grid]::SetColumn($showBtn,0)
[System.Windows.Controls.Grid]::SetRow($hideBtn,0);   [System.Windows.Controls.Grid]::SetColumn($hideBtn,1)
[System.Windows.Controls.Grid]::SetRow($statusBtn,0); [System.Windows.Controls.Grid]::SetColumn($statusBtn,2)

[System.Windows.Controls.Grid]::SetRow($applyBtn,1);  [System.Windows.Controls.Grid]::SetColumn($applyBtn,0)
[System.Windows.Controls.Grid]::SetRow($powerBtn,1);   [System.Windows.Controls.Grid]::SetColumn($powerBtn,1)
[System.Windows.Controls.Grid]::SetRow($exitBtn,1);    [System.Windows.Controls.Grid]::SetColumn($exitBtn,2)

$btnGrid.Children.Add($showBtn)
$btnGrid.Children.Add($hideBtn)
$btnGrid.Children.Add($statusBtn)
$btnGrid.Children.Add($applyBtn)
$btnGrid.Children.Add($powerBtn)
$btnGrid.Children.Add($exitBtn)

# =========================
# FOOTER
# =========================

$footer = New-Object System.Windows.Controls.StackPanel
$footer.Orientation = "Vertical"

$footer.Children.Add($btnGrid)

# Progress
$progress = New-Object System.Windows.Controls.ProgressBar
$progress.Height = 18
$progress.Maximum = 100
$progress.Margin = "0,10,0,0"

$footer.Children.Add($progress)

# Status Label
$statusLabel = New-Object System.Windows.Controls.TextBlock
$statusLabel.Text = "System Type: - | Cooling Support: -"
$statusLabel.HorizontalAlignment = "Center"
$statusLabel.Margin = "0,5,0,0"
$statusLabel.FontSize = 12
$statusLabel.FontWeight = "SemiBold"

$footer.Children.Add($statusLabel)

# =========================
# COPYRIGHT
# =========================

$copyright = New-Object System.Windows.Controls.Label
$copyright.Content = "Copyright © 2026 Allester Padovani | Microsoft Intune Engineer"
$copyright.HorizontalAlignment = "Center"
$copyright.Margin = "0,5,0,0"

$footer.Children.Add($copyright)

[System.Windows.Controls.Grid]::SetRow($footer,2)
$grid.Children.Add($footer)

# =========================
# LOG FUNCTION
# =========================

function Log($m){
    $output.AppendText("$m`r`n")
    $output.ScrollToEnd()

    $statusLabel.Text = "System Type: $(Get-SystemType) | Cooling Support: $(Test-CoolingSupport)"
}

# =========================
# STATUS CHECK
# =========================

function Get-Status {
    try {
        $v = (Get-ItemProperty -Path $RegPath -Name Attributes).Attributes
        if ($v -eq 1) { return "Hidden" }
        if ($v -eq 2) { return "Visible" }
        return "Unknown"
    } catch { return "Not Found" }
}

# =========================
# BUTTON EVENTS
# =========================

$showBtn.Add_Click({
    Set-ItemProperty -Path $RegPath -Name Attributes -Value 2
    Log "Policy Visible"
})

$hideBtn.Add_Click({
    Set-ItemProperty -Path $RegPath -Name Attributes -Value 1
    Log "Policy Hidden"
})

$statusBtn.Add_Click({
    $output.Clear()
    Log "Status: $(Get-Status)"
})

$applyBtn.Add_Click({

    $output.Clear()
    Log "Applying recommended settings..."

    if (-not (Test-CoolingSupport)) {
        Log "Cooling policy not supported"
        return
    }

    Set-ItemProperty -Path $RegPath -Name Attributes -Value 2
    Set-Cooling "AC_Active"
    Set-Cooling "DC_Passive"

    $progress.Value = 100
    Log "Done"
})

$powerBtn.Add_Click({
    Start-Process control.exe "/name Microsoft.PowerOptions"
})

$exitBtn.Add_Click({
    $window.Close()
})

# =========================
# LIVE UPDATE (NEW FIX)
# =========================

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(2)

$timer.Add_Tick({
    $statusLabel.Text = "System Type: $(Get-SystemType) | Cooling Support: $(Test-CoolingSupport)"
})

$timer.Start()

# =========================
# STARTUP
# =========================

Log "System initialized"
Log "Ready"

# =========================
# SHOW UI
# =========================

$window.Content = $grid
$window.ShowDialog() | Out-Null
