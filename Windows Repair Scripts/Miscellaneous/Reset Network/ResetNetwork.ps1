<#
.SYNOPSIS
    Network Reset Dashboard GUI.

.DESCRIPTION
    Provides a modern WPF GUI to reset Windows networking components.
    Performs TCP/IP reset, Winsock reset, DNS flush, IP renew,
    and network adapter restart with real-time logging and progress updates.
    A reboot is recommended after completion.

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
$window.Title = "Network Reset Dashboard"
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
$header.Text = "Network Reset Dashboard"
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

# Buttons
$btnPanel = New-Object System.Windows.Controls.StackPanel
$btnPanel.Orientation = 'Horizontal'
$btnPanel.HorizontalAlignment = 'Center'
$btnPanel.Margin = '0,0,0,10'

$resetBtn = New-Object System.Windows.Controls.Button
$resetBtn.Content = "Run Network Reset"
$resetBtn.Width = 200
$resetBtn.Margin = '5,0,5,0'
$btnPanel.Children.Add($resetBtn)

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

# ================== NETWORK RESET FUNCTION ==================
function Run-NetworkReset {

    $resetBtn.IsEnabled = $false
    $outputBox.Clear()
    $progress.Value = 0

    # STA runspace
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace

    $ps.AddScript({
        param($outputBox, $progress, $resetBtn)

        function Write-Log {
            param($text)
            $outputBox.Dispatcher.Invoke([action]{
                $outputBox.AppendText("$text`n")
                $outputBox.ScrollToEnd()
            })
        }

        Write-Log "Starting network reset..."
        Start-Sleep -Milliseconds 500

        $steps = @(
            @{ Name="Reset TCP/IP"; Action={
                Write-Log "Resetting TCP/IP stack..."
                netsh int ip reset | Out-Null
                Start-Sleep -Seconds 2
            }},
            @{ Name="Reset Winsock"; Action={
                Write-Log "Resetting Winsock..."
                netsh winsock reset | Out-Null
                Start-Sleep -Seconds 2
            }},
            @{ Name="Flush DNS"; Action={
                Write-Log "Flushing DNS cache..."
                ipconfig /flushdns | Out-Null
                Start-Sleep -Seconds 1
            }},
            @{ Name="Renew IP"; Action={
                Write-Log "Releasing IP address..."
                ipconfig /release | Out-Null
                Start-Sleep -Seconds 2
                Write-Log "Renewing IP address..."
                ipconfig /renew | Out-Null
                Start-Sleep -Seconds 2
            }},
            @{ Name="Restart Network Adapters"; Action={
                Write-Log "Restarting network adapters..."
                Get-NetAdapter |
                    Where-Object { $_.Status -ne "Disabled" } |
                    Restart-NetAdapter -Confirm:$false
                Start-Sleep -Seconds 3
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

        Write-Log "Network reset completed."
        Write-Log "A system reboot is recommended."
        $progress.Dispatcher.Invoke([action]{ $progress.Value = 100 })
        $resetBtn.Dispatcher.Invoke([action]{ $resetBtn.IsEnabled = $true })

    }).AddArgument($outputBox).AddArgument($progress).AddArgument($resetBtn)

    $ps.BeginInvoke() | Out-Null
}

# ================== BUTTON EVENT ==================
$resetBtn.Add_Click({ Run-NetworkReset })

# ================== SHOW WINDOW ==================
$window.Content = $grid
$window.ShowDialog() | Out-Null
