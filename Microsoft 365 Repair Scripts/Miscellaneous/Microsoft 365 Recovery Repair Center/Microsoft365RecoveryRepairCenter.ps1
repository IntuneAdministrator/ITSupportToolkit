<#
.SYNOPSIS
    Microsoft 365 Repair Dashboard GUI (PS 5.1 Compatible)

.DESCRIPTION
    Resets Microsoft 365 profiles & credentials and disables COM Add-ins,
    shows logs/progress in a WPF GUI.

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
$window.Title = "Microsoft 365 Recovery & Repair Center"
$window.SizeToContent = 'WidthAndHeight'
$window.ResizeMode = 'CanMinimize'
$window.WindowStartupLocation = 'CenterScreen'
$window.Background = 'White'

# ================== GRID ==================
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = '10'
for ($i=0; $i -lt 3; $i++) {
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
}

# ================== HEADER ==================
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Microsoft 365 Recovery & Repair Center"
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
$progress.Width = 520
$progress.Height = 20
$progress.Maximum = 100
$progress.Margin = '0,0,0,10'
$footer.Children.Add($progress)

$btnPanel = New-Object System.Windows.Controls.StackPanel
$btnPanel.Orientation = 'Horizontal'
$btnPanel.HorizontalAlignment = 'Center'

# Only two buttons now
$profileBtn     = New-Object System.Windows.Controls.Button
$profileBtn.Content     = "Profile Reset"
$profileBtn.Width       = 130
$profileBtn.Margin      = '5'
$btnPanel.Children.Add($profileBtn)

$comAddinsBtn   = New-Object System.Windows.Controls.Button
$comAddinsBtn.Content   = "Disable COM Add-ins"
$comAddinsBtn.Width     = 150
$comAddinsBtn.Margin    = '5'
$btnPanel.Children.Add($comAddinsBtn)

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

    # Disable buttons
    $profileBtn.IsEnabled=$false; $comAddinsBtn.IsEnabled=$false
    $outputBox.Clear(); $progress.Value=0

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript($Script).
        AddArgument($outputBox).
        AddArgument($progress).
        AddArgument($profileBtn).
        AddArgument($comAddinsBtn)
    $ps.BeginInvoke() | Out-Null
}

# ================== PROFILE RESET ==================
$ProfileScript = {
    param($outputBox,$progress,$profileBtn,$comAddinsBtn)
    Write-Log "👤 Resetting Office profiles and credentials..."
    # Delete Office credentials
    cmdkey /list | ForEach-Object { if ($_ -match "MicrosoftOffice") { cmdkey /delete:$($_.Split(':')[1].Trim()) } }
    # Remove Office identity registry keys
    Remove-Item "HKCU:\Software\Microsoft\Office\16.0\Common\Identity\Identities" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep 2
    $progress.Value=100; Write-Log "✅ Profile reset completed."
    $profileBtn.IsEnabled=$true; $comAddinsBtn.IsEnabled=$true
}

# ================== COM ADD-INS RESET ==================
$ComAddinsScript = {
    param($outputBox,$progress,$profileBtn,$comAddinsBtn)
    Write-Log "⚙️ Disabling all COM Add-ins..."
    $officeApps = "Word.Application","Excel.Application","Outlook.Application"
    foreach ($app in $officeApps) {
        try {
            $o = New-Object -ComObject $app
            $o.COMAddIns | ForEach-Object { $_.Connect = $false }
            $o.Quit()
        } catch {}
    }
    Start-Sleep 2
    $progress.Value=100; Write-Log "✅ COM Add-ins disabled."
    $profileBtn.IsEnabled=$true; $comAddinsBtn.IsEnabled=$true
}

# ================== BUTTON EVENTS ==================
$profileBtn.Add_Click({ Invoke-M365Task $ProfileScript })
$comAddinsBtn.Add_Click({ Invoke-M365Task $ComAddinsScript })

# ================== SHOW WINDOW ==================
$window.Content = $grid
$window.ShowDialog() | Out-Null
