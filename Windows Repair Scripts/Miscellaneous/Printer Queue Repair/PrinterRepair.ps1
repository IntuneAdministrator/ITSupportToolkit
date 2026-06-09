<#
.SYNOPSIS
    Printer Queue Cleanup Dashboard GUI.

.DESCRIPTION
    Provides a modern WPF GUI to clear ALL printer queues by stopping
    the Print Spooler service, deleting queued jobs, and restarting it.
    Displays real-time logging and progress updates.
    Buttons are disabled while the cleanup is running.

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
$window.Title = "Printer Queue Cleanup Dashboard"
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
$header.Text = "Printer Queue Cleanup Dashboard"
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

# Cleanup button
$cleanupBtn = New-Object System.Windows.Controls.Button
$cleanupBtn.Content = "Clear All Printer Queues"
$cleanupBtn.Width = 220
$cleanupBtn.Margin = '5,0,5,0'
$btnPanel.Children.Add($cleanupBtn)

$footer.Children.Add($btnPanel)

# Copyright
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

# ================== PRINTER CLEANUP FUNCTION ==================
function Run-PrinterCleanup {

    $cleanupBtn.IsEnabled = $false
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
        param($outputBox, $progress, $cleanupBtn)

        function Write-Log {
            param($text)
            $outputBox.Dispatcher.Invoke([action]{
                $outputBox.AppendText("$text`n")
                $outputBox.ScrollToEnd()
            })
        }

        Write-Log "Starting printer queue cleanup..."
        Start-Sleep -Milliseconds 500

        $steps = @(
            @{ Name="Stopping Print Spooler"; Action={
                Write-Log "Stopping Print Spooler service..."
                Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }},
            @{ Name="Clearing Print Queue"; Action={
                Write-Log "Clearing all printer queue files..."
                Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" `
                    -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }},
            @{ Name="Starting Print Spooler"; Action={
                Write-Log "Starting Print Spooler service..."
                Start-Service -Name Spooler -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
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

        Write-Log "Printer queue cleanup completed successfully."
        $progress.Dispatcher.Invoke([action]{ $progress.Value = 100 })
        $cleanupBtn.Dispatcher.Invoke([action]{ $cleanupBtn.IsEnabled = $true })

    }).AddArgument($outputBox).AddArgument($progress).AddArgument($cleanupBtn)

    $ps.BeginInvoke() | Out-Null
}

# ================== BUTTON EVENT ==================
$cleanupBtn.Add_Click({ Run-PrinterCleanup })

# ================== SHOW WINDOW ==================
$window.Content = $grid
$window.ShowDialog() | Out-Null
