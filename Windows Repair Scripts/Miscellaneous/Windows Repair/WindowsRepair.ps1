<#
.SYNOPSIS
    Windows Repair Dashboard GUI for running DISM, SFC, and Windows Update repairs.

.DESCRIPTION
    Provides a modern WPF GUI with a live log and dynamic progress bar.
    Features two main repair actions:
        1. Windows Repair – runs DISM Online and System File Checker (SFC)
        2. Windows Update Repair – stops services, clears caches, and restarts services
    Real-time output is displayed in a text box, with incremental progress for long-running operations.
    Buttons are disabled while operations are running to prevent multiple simultaneous executions.

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
$window.Title = "Windows Repair Dashboard"
$window.SizeToContent = 'WidthAndHeight'
$window.ResizeMode = 'CanMinimize'
$window.WindowStartupLocation = 'CenterScreen'
$window.Background = 'White'

# ================== GRID ==================
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = '10'
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Header
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Output
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Footer

# ================== HEADER ==================
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Windows Repair Dashboard"
$header.FontSize = 16
$header.FontWeight = 'Bold'
$header.HorizontalAlignment = 'Center'
$header.Margin = '0,0,0,10'
[System.Windows.Controls.Grid]::SetRow($header,0)
$grid.Children.Add($header)

# ================== OUTPUT TEXTBOX ==================
$outputBox = New-Object System.Windows.Controls.TextBox
$outputBox.Text = "Ready..."
$outputBox.FontFamily = 'Consolas'
$outputBox.FontSize = 12
$outputBox.IsReadOnly = $true
$outputBox.VerticalScrollBarVisibility = 'Auto'
$outputBox.HorizontalScrollBarVisibility = 'Auto'
$outputBox.TextWrapping = 'Wrap'
$outputBox.AcceptsReturn = $true
$outputBox.MinWidth = 500
$outputBox.MinHeight = 300
[System.Windows.Controls.Grid]::SetRow($outputBox,1)
$grid.Children.Add($outputBox)

# ================== FOOTER ==================
$footer = New-Object System.Windows.Controls.StackPanel
$footer.Orientation = 'Vertical'
$footer.HorizontalAlignment = 'Center'
$footer.VerticalAlignment = 'Center'
$footer.Margin = '10'

# Progress bar
$progress = New-Object System.Windows.Controls.ProgressBar
$progress.Width = 400
$progress.Height = 20
$progress.Minimum = 0
$progress.Maximum = 100
$progress.Value = 0
$progress.Margin = '0,0,0,10'
$footer.Children.Add($progress)

# Buttons container
$btnPanel = New-Object System.Windows.Controls.StackPanel
$btnPanel.Orientation = 'Horizontal'
$btnPanel.HorizontalAlignment = 'Center'
$btnPanel.Margin = '0,0,0,10'

# Windows Repair button
$repairBtn = New-Object System.Windows.Controls.Button
$repairBtn.Content = "Run Windows Repair"
$repairBtn.Width = 150
$repairBtn.Margin = '5,0,5,0'
$btnPanel.Children.Add($repairBtn)

# Windows Update Repair button
$wuRepairBtn = New-Object System.Windows.Controls.Button
$wuRepairBtn.Content = "Run Windows Update Repair"
$wuRepairBtn.Width = 200
$wuRepairBtn.Margin = '5,0,5,0'
$btnPanel.Children.Add($wuRepairBtn)

$footer.Children.Add($btnPanel)

# Copyright label
$copyright = New-Object System.Windows.Controls.Label
$copyright.Content = "Copyright " + [char]169 + " 2026 Allester Padovani | Microsoft Intune Engineer"
$copyright.HorizontalAlignment = 'Center'
$footer.Children.Add($copyright)

[System.Windows.Controls.Grid]::SetRow($footer,2)
$grid.Children.Add($footer)

# ================== LOG FUNCTION ==================
function Write-Log {
    param($text)
    $outputBox.Dispatcher.Invoke([action]{ 
        $outputBox.AppendText("$text`n")
        $outputBox.ScrollToEnd()
    })
}

# ================== WINDOWS REPAIR FUNCTION ==================
function Run-WindowsRepair {
    $repairBtn.IsEnabled = $false
    $wuRepairBtn.IsEnabled = $false
    $outputBox.Clear()
    $progress.Value = 0

    # Create STA runspace
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    $ps.AddScript({
        param($outputBox, $progress, $repairBtn, $wuRepairBtn)

        function Write-Log {
            param($text)
            $outputBox.Dispatcher.Invoke([action]{ 
                $outputBox.AppendText("$text`n")
                $outputBox.ScrollToEnd()
            })
        }

        Write-Log "Starting Windows Repair..."
        Start-Sleep -Milliseconds 500

        # ================== DISM ==================
        Write-Log "Running DISM Online..."
        $progress.Dispatcher.Invoke([action]{ $progress.IsIndeterminate = $true })
        Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /restorehealth" -NoNewWindow -Wait
        $progress.Dispatcher.Invoke([action]{ $progress.IsIndeterminate = $false })
        Write-Log "DISM Completed."

        # ================== SFC ==================
        Write-Log "Running System File Checker (SFC)..."
        $progress.Dispatcher.Invoke([action]{ $progress.IsIndeterminate = $true })
        Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -NoNewWindow -Wait
        $progress.Dispatcher.Invoke([action]{ $progress.IsIndeterminate = $false })
        Write-Log "SFC Completed."

        # Finish
        Write-Log "Windows Repair Finished."
        $progress.Dispatcher.Invoke([action]{ $progress.Value = 100 })
        $repairBtn.Dispatcher.Invoke([action]{ $repairBtn.IsEnabled = $true })
        $wuRepairBtn.Dispatcher.Invoke([action]{ $wuRepairBtn.IsEnabled = $true })
    }).AddArgument($outputBox).AddArgument($progress).AddArgument($repairBtn).AddArgument($wuRepairBtn)

    $ps.BeginInvoke() | Out-Null
}

# ================== WINDOWS UPDATE REPAIR FUNCTION ==================
function Run-WindowsUpdateRepair {
    $repairBtn.IsEnabled = $false
    $wuRepairBtn.IsEnabled = $false
    $outputBox.Clear()
    $progress.Value = 0

    # Create STA runspace
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    $ps.AddScript({
        param($outputBox, $progress, $repairBtn, $wuRepairBtn)

        function Write-Log {
            param($text)
            $outputBox.Dispatcher.Invoke([action]{ 
                $outputBox.AppendText("$text`n")
                $outputBox.ScrollToEnd()
            })
        }

        Write-Log "Starting Windows Update Repair..."
        Start-Sleep -Milliseconds 500

        $steps = @(
            @{ Name="Stopping Services"; Action={
                $services = @("wuauserv","bits","cryptsvc")
                foreach ($svc in $services) {
                    Write-Log "Stopping $svc..."
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Milliseconds 500
                }
            }},
            @{ Name="Clearing Caches"; Action={
                $paths = @(
                    "$env:SystemRoot\SoftwareDistribution\Download\*",
                    "$env:SystemRoot\System32\catroot2\*"
                )
                foreach ($path in $paths) {
                    Write-Log "Clearing $path..."
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Milliseconds 500
                }
            }},
            @{ Name="Starting Services"; Action={
                $services = @("wuauserv","bits","cryptsvc")
                foreach ($svc in $services) {
                    Write-Log "Starting $svc..."
                    Start-Service -Name $svc -ErrorAction SilentlyContinue
                    Start-Sleep -Milliseconds 500
                }
            }}
        )

        $total = $steps.Count
        $i = 0
        foreach ($step in $steps) {
            $i++
            Write-Log "=== $($step.Name) ==="
            & $step.Action
            $percent = [math]::Round(($i / $total) * 100)
            $progress.Dispatcher.Invoke([action]{ $progress.Value = $percent })
        }

        Write-Log "Windows Update Repair Finished."
        $progress.Dispatcher.Invoke([action]{ $progress.Value = 100 })
        $repairBtn.Dispatcher.Invoke([action]{ $repairBtn.IsEnabled = $true })
        $wuRepairBtn.Dispatcher.Invoke([action]{ $wuRepairBtn.IsEnabled = $true })
    }).AddArgument($outputBox).AddArgument($progress).AddArgument($repairBtn).AddArgument($wuRepairBtn)

    $ps.BeginInvoke() | Out-Null
}

# ================== BUTTON EVENTS ==================
$repairBtn.Add_Click({ Run-WindowsRepair })
$wuRepairBtn.Add_Click({ Run-WindowsUpdateRepair })

# ================== SHOW WINDOW ==================
$window.Content = $grid
$window.ShowDialog() | Out-Null
