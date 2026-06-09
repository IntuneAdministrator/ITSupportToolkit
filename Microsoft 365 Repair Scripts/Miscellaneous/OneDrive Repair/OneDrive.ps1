<#
.SYNOPSIS
    Advanced OneDrive Repair Dashboard GUI (PS 5.1 Compatible)

.DESCRIPTION
    Performs OneDrive health detection, silent reset,
    cache & token cleanup, restart, and optional full reinstall.
    Displays real-time progress and logging via WPF.

.AUTHOR
    Name        : Allester Padovani
    Title       : Microsoft Intune Engineer
    Script Ver. : 1.0
    Date        : 01.28.2026
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# ================== WINDOW ==================
$window = New-Object System.Windows.Window
$window.Title = "OneDrive Repair Dashboard (Advanced)"
$window.SizeToContent = 'WidthAndHeight'
$window.ResizeMode = 'CanMinimize'
$window.WindowStartupLocation = 'CenterScreen'
$window.Background = 'White'

# ================== GRID ==================
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = '10'
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))

# ================== HEADER ==================
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "OneDrive Repair Dashboard (Advanced)"
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

# Progress bar
$progress = New-Object System.Windows.Controls.ProgressBar
$progress.Width = 420
$progress.Height = 20
$progress.Maximum = 100
$progress.Margin = '0,0,0,10'
$footer.Children.Add($progress)

# Button panel
$btnPanel = New-Object System.Windows.Controls.StackPanel
$btnPanel.Orientation = 'Horizontal'
$btnPanel.HorizontalAlignment = 'Center'

$repairBtn = New-Object System.Windows.Controls.Button
$repairBtn.Content = "Repair OneDrive"
$repairBtn.Width = 160
$repairBtn.Margin = '5'
$btnPanel.Children.Add($repairBtn)

$reinstallBtn = New-Object System.Windows.Controls.Button
$reinstallBtn.Content = "Full Reinstall"
$reinstallBtn.Width = 160
$reinstallBtn.Margin = '5'
$btnPanel.Children.Add($reinstallBtn)

$footer.Children.Add($btnPanel)

# ================== COPYRIGHT LABEL ==================
$copyright = New-Object System.Windows.Controls.Label
$copyright.Content = "Copyright " + [char]169 + " 2026 Allester Padovani | Microsoft Intune Engineer"
$copyright.HorizontalAlignment = 'Center'
$copyright.FontSize = 12
$footer.Children.Add($copyright)

# Add footer to grid
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
function Invoke-OneDriveTask {
    param([scriptblock]$Script)

    $repairBtn.IsEnabled = $false
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
        AddArgument($repairBtn).
        AddArgument($reinstallBtn)

    $ps.BeginInvoke() | Out-Null
}

# ================== REPAIR SCRIPT ==================
$RepairScript = {
    param($outputBox,$progress,$repairBtn,$reinstallBtn)

    function Write-Log {
        param($m)
        $outputBox.Dispatcher.Invoke([action]{
            $outputBox.AppendText("$m`n")
            $outputBox.ScrollToEnd()
        })
    }

    $exe = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"

    Write-Log "Performing OneDrive health check..."

    if (-not (Test-Path $exe)) {
        Write-Log "OneDrive is not installed."
        $repairBtn.Dispatcher.Invoke([action]{ $repairBtn.IsEnabled = $true })
        $reinstallBtn.Dispatcher.Invoke([action]{ $reinstallBtn.IsEnabled = $true })
        return
    }

    $running = Get-Process OneDrive -ErrorAction SilentlyContinue
    if ($running) {
        Write-Log "OneDrive is running (possible unstable state)"
    } else {
        Write-Log "OneDrive is not running"
    }

    $steps = @(
        @{
            Name = "Stop OneDrive"
            Action = {
                Write-Log "Stopping OneDrive..."
                Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
                Start-Sleep 2
            }
        },
        @{
            Name = "Reset Client"
            Action = {
                Write-Log "Resetting OneDrive..."
                Start-Process -FilePath $exe -ArgumentList "/reset" -NoNewWindow
                Start-Sleep 10
            }
        },
        @{
            Name = "Clear Cache & Tokens"
            Action = {
                Write-Log "Clearing cache and authentication data..."
                Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive\logs" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item "$env:LOCALAPPDATA\Microsoft\OneDrive\settings" -Recurse -Force -ErrorAction SilentlyContinue
                Start-Sleep 2
            }
        },
        @{
            Name = "Restart OneDrive"
            Action = {
                Write-Log "Restarting OneDrive..."
                Start-Process -FilePath $exe -NoNewWindow
                Start-Sleep 3
            }
        }
    )

    $i = 0
    foreach ($step in $steps) {
        $i++
        Write-Log "=== $($step.Name) ==="
        & $step.Action
        $progress.Dispatcher.Invoke([action]{
            $progress.Value = [math]::Round(($i / $steps.Count) * 100)
        })
    }

    Write-Log "✅ OneDrive repair completed successfully."
    Write-Log "ℹ️ If sync does not resume, sign out/in or reboot."

    $repairBtn.Dispatcher.Invoke([action]{ $repairBtn.IsEnabled = $true })
    $reinstallBtn.Dispatcher.Invoke([action]{ $reinstallBtn.IsEnabled = $true })
}

# ================== REINSTALL SCRIPT ==================
$ReinstallScript = {
    param($outputBox,$progress,$repairBtn,$reinstallBtn)

    function Write-Log {
        param($m)
        $outputBox.Dispatcher.Invoke([action]{
            $outputBox.AppendText("$m`n")
            $outputBox.ScrollToEnd()
        })
    }

    Write-Log "🪟 Starting OneDrive full reinstall..."

    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
    Start-Sleep 2

    $setup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    if (-not (Test-Path $setup)) {
        $setup = "$env:SystemRoot\System32\OneDriveSetup.exe"
    }

    Write-Log "Uninstalling OneDrive..."
    Start-Process -FilePath $setup -ArgumentList "/uninstall" -Wait

    Write-Log "Reinstalling OneDrive..."
    Start-Process -FilePath $setup -Wait

    Write-Log "Restarting OneDrive..."
    Start-Process "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"

    Write-Log "OneDrive reinstall completed."
    $progress.Dispatcher.Invoke([action]{ $progress.Value = 100 })

    $repairBtn.Dispatcher.Invoke([action]{ $repairBtn.IsEnabled = $true })
    $reinstallBtn.Dispatcher.Invoke([action]{ $reinstallBtn.IsEnabled = $true })
}

# ================== BUTTON EVENTS ==================
$repairBtn.Add_Click({ Invoke-OneDriveTask $RepairScript })
$reinstallBtn.Add_Click({ Invoke-OneDriveTask $ReinstallScript })

# ================== SHOW WINDOW ==================
$window.Content = $grid
$window.ShowDialog() | Out-Null
