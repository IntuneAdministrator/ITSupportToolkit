<#
.SYNOPSIS
    Microsoft 365 Repair Dashboard GUI (PS 5.1 Compatible)

.DESCRIPTION
    Detects installed Microsoft 365 products, performs Quick or Online Repair,
    optionally does a full reinstall, and shows logs/progress in a WPF GUI.

.AUTHOR
    Name        : Allester Padovani
    Title       : Microsoft Intune Engineer
    Script Ver. : 1.0
    Date        : 01.22.2026
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# ================== WINDOW ==================
$window = New-Object System.Windows.Window
$window.Title = "Microsoft 365 Repair Dashboard"
$window.SizeToContent = 'WidthAndHeight'
$window.ResizeMode = 'CanMinimize'
$window.WindowStartupLocation = 'CenterScreen'
$window.Background = 'White'

# ================== GRID ==================
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = '10'
for ($i=0; $i -lt 4; $i++) {
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
}

# ================== HEADER ==================
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Microsoft 365 Repair Dashboard"
$header.FontSize = 16
$header.FontWeight = 'Bold'
$header.HorizontalAlignment = 'Center'
$header.Margin = '0,0,0,10'
[System.Windows.Controls.Grid]::SetRow($header,0)
$grid.Children.Add($header)

# ================== OUTPUT ==================
$outputBox = New-Object System.Windows.Controls.TextBox
$outputBox.Text = "Ready..."
$outputBox.FontFamily = 'Consolas'
$outputBox.FontSize = 12
$outputBox.IsReadOnly = $true
$outputBox.VerticalScrollBarVisibility = 'Auto'
$outputBox.HorizontalScrollBarVisibility = 'Auto'
$outputBox.TextWrapping = 'Wrap'
$outputBox.AcceptsReturn = $true
$outputBox.MinWidth = 520
$outputBox.MinHeight = 320
[System.Windows.Controls.Grid]::SetRow($outputBox,1)
$grid.Children.Add($outputBox)

# ================== FOOTER ==================
$footer = New-Object System.Windows.Controls.StackPanel
$footer.Orientation = 'Vertical'
$footer.HorizontalAlignment = 'Center'
$footer.Margin = '10'

$progress = New-Object System.Windows.Controls.ProgressBar
$progress.Width = 420
$progress.Height = 20
$progress.Maximum = 100
$progress.Margin = '0,0,0,10'
$footer.Children.Add($progress)

$btnPanel = New-Object System.Windows.Controls.StackPanel
$btnPanel.Orientation = 'Horizontal'
$btnPanel.HorizontalAlignment = 'Center'

$detectBtn = New-Object System.Windows.Controls.Button
$detectBtn.Content = "Detect Products"
$detectBtn.Width = 130
$detectBtn.Margin = '5'
$btnPanel.Children.Add($detectBtn)

$quickBtn = New-Object System.Windows.Controls.Button
$quickBtn.Content = "Quick Repair"
$quickBtn.Width = 130
$quickBtn.Margin = '5'
$btnPanel.Children.Add($quickBtn)

$onlineBtn = New-Object System.Windows.Controls.Button
$onlineBtn.Content = "Online Repair"
$onlineBtn.Width = 130
$onlineBtn.Margin = '5'
$btnPanel.Children.Add($onlineBtn)

$reinstallBtn = New-Object System.Windows.Controls.Button
$reinstallBtn.Content = "Full Reinstall"
$reinstallBtn.Width = 130
$reinstallBtn.Margin = '5'
$btnPanel.Children.Add($reinstallBtn)

$footer.Children.Add($btnPanel)

# ================== COPYRIGHT ==================
$copyright = New-Object System.Windows.Controls.Label
$copyright.Content = "Copyright " + [char]169 + " 2026 Allester Padovani | Microsoft Intune Engineer"
$copyright.HorizontalAlignment = 'Center'
$footer.Children.Add($copyright)

[System.Windows.Controls.Grid]::SetRow($footer,2)
$grid.Children.Add($footer)

# ================== LOG FUNCTION ==================
function Write-Log {
    param($msg)
    $outputBox.Dispatcher.Invoke([action]{
        $outputBox.AppendText("$msg`n")
        $outputBox.ScrollToEnd()
    })
}

# ================== RUNSPACE INVOKER ==================
function Invoke-M365Task {
    param([scriptblock]$Script)

    $detectBtn.IsEnabled = $false
    $quickBtn.IsEnabled = $false
    $onlineBtn.IsEnabled = $false
    $reinstallBtn.IsEnabled = $false
    $outputBox.Clear()
    $progress.Value = 0

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript($Script).
        AddArgument($outputBox).
        AddArgument($progress).
        AddArgument($detectBtn).
        AddArgument($quickBtn).
        AddArgument($onlineBtn).
        AddArgument($reinstallBtn)

    $ps.BeginInvoke() | Out-Null
}

# ================== DETECT SCRIPT ==================
$DetectScript = {
    param($outputBox,$progress,$detectBtn,$quickBtn,$onlineBtn,$reinstallBtn)

    function Write-Log { param($msg) $outputBox.Dispatcher.Invoke([action]{ $outputBox.AppendText("$msg`n"); $outputBox.ScrollToEnd() }) }

    Write-Log "Detecting installed Microsoft 365 products..."

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun\Configuration"
    )

    $products = @()
    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            try {
                $config = Get-ItemProperty -Path $path
                if ($config.ProductReleaseIds) { $products += $config.ProductReleaseIds -split "," }
            } catch {}
        }
    }

    if ($products.Count -eq 0) {
        Write-Log "No Microsoft 365 Click-to-Run products found."
    } else {
        Write-Log "Installed Microsoft 365 products:"
        $i = 0
        $total = $products.Count
        foreach ($p in $products) {
            $i++
            Write-Log " - $p"
            # Dynamic progress
            $progress.Dispatcher.Invoke([action]{ $progress.Value = [math]::Round(($i / $total) * 100) })
            Start-Sleep -Milliseconds 200
        }
    }

    # Re-enable buttons
    $detectBtn.Dispatcher.Invoke([action]{ $detectBtn.IsEnabled = $true })
    $quickBtn.Dispatcher.Invoke([action]{ $quickBtn.IsEnabled = $true })
    $onlineBtn.Dispatcher.Invoke([action]{ $onlineBtn.IsEnabled = $true })
    $reinstallBtn.Dispatcher.Invoke([action]{ $reinstallBtn.IsEnabled = $true })
}

# ================== REPAIR SCRIPT ==================
$RepairScript = {
    param($outputBox,$progress,$detectBtn,$quickBtn,$onlineBtn,$reinstallBtn,$Type="Quick")

    function Write-Log { param($m) $outputBox.Dispatcher.Invoke([action]{ $outputBox.AppendText("$m`n"); $outputBox.ScrollToEnd() }) }

    Write-Log "⚠️ Closing running Office apps..."
    Get-Process winword,excel,outlook,powerpnt -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 1

    $exe = "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    if (-not (Test-Path $exe)) { Write-Log "Click-to-Run client not found."; return }

    $steps = @(
        @{Name="Starting Repair"; Action={ Start-Process -FilePath $exe -ArgumentList "/repair PROPLUS /$Type" -Wait }}
    )

    $total = $steps.Count
    $i = 0
    foreach ($step in $steps) {
        $i++
        Write-Log "🔧 $($step.Name)..."
        & $step.Action
        # Smooth progress bar
        for ($j=[math]::Round((($i-1)/$total)*100); $j -le [math]::Round(($i/$total)*100); $j++) {
            $progress.Dispatcher.Invoke([action]{ $progress.Value = $j })
            Start-Sleep -Milliseconds 20
        }
    }

    Write-Log "$Type Repair completed."

    # Re-enable buttons
    $detectBtn.Dispatcher.Invoke([action]{ $detectBtn.IsEnabled = $true })
    $quickBtn.Dispatcher.Invoke([action]{ $quickBtn.IsEnabled = $true })
    $onlineBtn.Dispatcher.Invoke([action]{ $onlineBtn.IsEnabled = $true })
    $reinstallBtn.Dispatcher.Invoke([action]{ $reinstallBtn.IsEnabled = $true })
}

# ================== FULL REINSTALL SCRIPT ==================
$ReinstallScript = {
    param($outputBox,$progress,$detectBtn,$quickBtn,$onlineBtn,$reinstallBtn)

    function Write-Log { param($m) $outputBox.Dispatcher.Invoke([action]{ $outputBox.AppendText("$m`n"); $outputBox.ScrollToEnd() }) }

    Write-Log "Closing running Office apps..."
    Get-Process winword,excel,outlook,powerpnt -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 1

    $exe = "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    if (-not (Test-Path $exe)) { Write-Log "Click-to-Run client not found."; return }

    $steps = @(
        @{Name="Uninstalling Office"; Action={ Start-Process -FilePath $exe -ArgumentList "/uninstall PROPLUS /quiet" -Wait }},
        @{Name="Reinstalling Office"; Action={ Start-Process -FilePath $exe -ArgumentList "/configure install.xml" -Wait }}
    )

    $total = $steps.Count
    $i = 0
    foreach ($step in $steps) {
        $i++
        Write-Log "$($step.Name)..."
        & $step.Action
        # Smooth progress bar
        for ($j=[math]::Round((($i-1)/$total)*100); $j -le [math]::Round(($i/$total)*100); $j++) {
            $progress.Dispatcher.Invoke([action]{ $progress.Value = $j })
            Start-Sleep -Milliseconds 20
        }
    }

    Write-Log "Full reinstall completed."

    # Re-enable buttons
    $detectBtn.Dispatcher.Invoke([action]{ $detectBtn.IsEnabled = $true })
    $quickBtn.Dispatcher.Invoke([action]{ $quickBtn.IsEnabled = $true })
    $onlineBtn.Dispatcher.Invoke([action]{ $onlineBtn.IsEnabled = $true })
    $reinstallBtn.Dispatcher.Invoke([action]{ $reinstallBtn.IsEnabled = $true })
}

# ================== BUTTON EVENTS ==================
$detectBtn.Add_Click({ Invoke-M365Task $DetectScript })
$quickBtn.Add_Click({ Invoke-M365Task { & $RepairScript $args "Quick" } })
$onlineBtn.Add_Click({ Invoke-M365Task { & $RepairScript $args "Online" } })
$reinstallBtn.Add_Click({ Invoke-M365Task $ReinstallScript })

# ================== SHOW WINDOW ==================
$window.Content = $grid
$window.ShowDialog() | Out-Null
