<#
.SYNOPSIS
    Remote Entra (Azure AD) Sync Dashboard GUI - Single Credential Prompt

.DESCRIPTION
    Dashboard GUI to connect to a predefined remote client and run Full/Delta Import,
    Full/Delta Sync, Export. Prompts for credentials once and reuses them.
    Allows local restart of Azure AD Connect services.

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

# ================== GLOBALS ==================
$global:StoredCredential    = $null
$global:RemoteComputer      = "Client1"
$global:RemoteSession       = $null
$global:IsConnected         = $false
$global:InstructionsViewed  = $false

# ================== WINDOW ==================
$window = New-Object System.Windows.Window
$window.Title = "Remote Entra Sync Dashboard"
$window.SizeToContent = 'WidthAndHeight'
$window.ResizeMode = 'CanMinimize'
$window.WindowStartupLocation = 'CenterScreen'
$window.Background = 'White'

# ================== GRID ==================
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = '10'

# Rows: Header | Output | Progress | Buttons | Footer
for ($i = 0; $i -lt 5; $i++) {
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
}

# ================== HEADER ==================
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Remote Entra (Azure AD) Sync Dashboard"
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
$outputBox.MinHeight = 300
[System.Windows.Controls.Grid]::SetRow($outputBox,1)
$grid.Children.Add($outputBox)

# ================== PROGRESS ==================
$progress = New-Object System.Windows.Controls.ProgressBar
$progress.Width = 520
$progress.Height = 20
$progress.Maximum = 100
$progress.Margin = '0,0,0,10'
[System.Windows.Controls.Grid]::SetRow($progress,2)
$grid.Children.Add($progress)

# ================== BUTTON FACTORY ==================
function Create-Button {
    param($content, $width, $enabled = $true)
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $content
    $btn.Width = $width
    $btn.Margin = '5'
    $btn.IsEnabled = $enabled
    return $btn
}

# ================== BUTTON ROWS ==================

# ---- Row 1: Sync Operations ----
$row1 = New-Object System.Windows.Controls.WrapPanel
$row1.HorizontalAlignment = 'Center'

$btnFullImport  = Create-Button "Full Import" 120 $false
$btnDeltaImport = Create-Button "Delta Import" 120 $false
$btnFullSync    = Create-Button "Full Sync" 120 $false
$btnDeltaSync   = Create-Button "Delta Sync" 120 $false
$btnExport      = Create-Button "Export" 120 $false

$row1.Children.Add($btnFullImport)
$row1.Children.Add($btnDeltaImport)
$row1.Children.Add($btnFullSync)
$row1.Children.Add($btnDeltaSync)
$row1.Children.Add($btnExport)

# ---- Row 2: Access / Safety ----
$row2 = New-Object System.Windows.Controls.WrapPanel
$row2.HorizontalAlignment = 'Center'
$row2.Margin = '0,5,0,0'

$btnConnect          = Create-Button "Connect User" 140 $false
$btnDisconnect       = Create-Button "Disconnect User" 160 $false
$btnRestartService   = Create-Button "Restart Service (Local)" 180 $false
$btnViewInstructions = Create-Button "View Script Instructions (Required)" 260 $true

$row2.Children.Add($btnConnect)
$row2.Children.Add($btnDisconnect)
$row2.Children.Add($btnRestartService)
$row2.Children.Add($btnViewInstructions)

# ---- Stack Rows ----
$buttonStack = New-Object System.Windows.Controls.StackPanel
$buttonStack.HorizontalAlignment = 'Center'
$buttonStack.Children.Add($row1)
$buttonStack.Children.Add($row2)

[System.Windows.Controls.Grid]::SetRow($buttonStack,3)
$grid.Children.Add($buttonStack)

# ================== FOOTER ==================
$footer = New-Object System.Windows.Controls.StackPanel
$footer.HorizontalAlignment = 'Center'
$footer.Margin = '0,10,0,0'

$copyright = New-Object System.Windows.Controls.Label
$copyright.Content = "Copyright " + [char]169 + " 2026 Allester Padovani | Microsoft Intune Engineer"
$copyright.FontSize = 12
$copyright.HorizontalAlignment = 'Center'

$footer.Children.Add($copyright) | Out-Null
[System.Windows.Controls.Grid]::SetRow($footer,4)
$grid.Children.Add($footer)

# ================== LOG FUNCTION ==================
function Write-Log {
    param($msg)
    $outputBox.Dispatcher.Invoke([action]{
        $outputBox.AppendText("$msg`n")
        $outputBox.ScrollToEnd()
    })
}

# ================== ENTRA SYNC SCRIPT ==================
$buttons = @(
    $btnFullImport,
    $btnDeltaImport,
    $btnFullSync,
    $btnDeltaSync,
    $btnExport
)

$EntraSyncScript = {
    param($outputBox, $progress, $btn, $buttons)

    function Write-Log {
        param($m)
        $outputBox.Dispatcher.Invoke([action]{
            $outputBox.AppendText("$m`n")
            $outputBox.ScrollToEnd()
        })
    }

    if (-not $global:IsConnected -or -not $global:RemoteSession) {
        Write-Log "Error: Not connected to any remote computer."
        return
    }

    foreach ($b in $buttons) { $b.Dispatcher.Invoke([action]{ $b.IsEnabled = $false }) }
    $progress.Dispatcher.Invoke([action]{ $progress.Value = 0 })
    Write-Log "Running $($btn.Content) on $($global:RemoteComputer)..."

    $progressRunning = $true

    # ===== Animate progress bar continuously =====
    $progressAnimator = {
        param($progress, [ref]$running)
        $val = 0
        while ($running.Value) {
            $val = ($val + 5) % 100
            $progress.Dispatcher.Invoke([action]{ $progress.Value = $val })
            Start-Sleep 0.1
        }
    }

    $animatorPs = [powershell]::Create()
    $animatorPs.Runspace = [runspacefactory]::CreateRunspace()
    $animatorPs.Runspace.ApartmentState = "STA"
    $animatorPs.Runspace.Open()
    $animatorPs.AddScript($progressAnimator).AddArgument($progress).AddArgument([ref]$progressRunning) | Out-Null
    $animatorPs.BeginInvoke() | Out-Null

    try {
        switch ($btn.Content) {
            "Full Import"  { $cmd = { Import-Module ADSync; Start-ADSyncImport -Full } }
            "Delta Import" { $cmd = { Import-Module ADSync; Start-ADSyncImport -Delta } }
            "Full Sync"    { $cmd = { Import-Module ADSync; Start-ADSyncSyncCycle -PolicyType Initial } }
            "Delta Sync"   { $cmd = { Import-Module ADSync; Start-ADSyncSyncCycle -PolicyType Delta } }
            "Export"       { $cmd = { Import-Module ADSync; Start-ADSyncExport -Full } }
        }

        Invoke-Command -Session $global:RemoteSession -ScriptBlock $cmd -Credential $global:StoredCredential
        Write-Log "$($btn.Content) completed successfully."
    }
    catch {
        Write-Log "Error: $_"
    }
    finally {
        $progressRunning = $false
        Start-Sleep 0.2
        $progress.Dispatcher.Invoke([action]{ $progress.Value = 100 })
        foreach ($b in $buttons) { $b.Dispatcher.Invoke([action]{ $b.IsEnabled = $true }) }
    }
}

function Invoke-EntraTask {
    param([scriptblock]$Script, $btn)

    $ps = [powershell]::Create()
    $ps.Runspace = [runspacefactory]::CreateRunspace()
    $ps.Runspace.ApartmentState = "STA"
    $ps.Runspace.Open()

    $ps.AddScript($Script).
        AddArgument($outputBox).
        AddArgument($progress).
        AddArgument($btn).
        AddArgument($buttons)

    $ps.BeginInvoke() | Out-Null
}

foreach ($btn in $buttons) {
    $btn.Add_Click({ Invoke-EntraTask $EntraSyncScript $btn })
}

# ================== CONNECT / DISCONNECT ==================
$btnConnect.Add_Click({
    if ($global:RemoteSession) { Write-Log "Already connected."; return }

    $outputBox.Clear()
    Write-Log "Prompting for credentials..."
    $cred = Get-Credential -Message "Enter admin credentials for $($global:RemoteComputer)"

    try {
        $global:RemoteSession = New-PSSession -ComputerName $global:RemoteComputer -Credential $cred
        $global:StoredCredential = $cred
        $global:IsConnected = $true

        Write-Log "Connected successfully."
        foreach ($b in $buttons) { $b.IsEnabled = $true }
        $btnDisconnect.IsEnabled = $true
    }
    catch {
        Write-Log "Connection failed: $_"
    }
})

$btnDisconnect.Add_Click({
    if ($global:RemoteSession) {
        Remove-PSSession $global:RemoteSession
        $global:RemoteSession = $null
    }

    $global:IsConnected = $false
    $global:StoredCredential = $null
    foreach ($b in $buttons) { $b.IsEnabled = $false }
    $btnDisconnect.IsEnabled = $false
    $btnConnect.IsEnabled = $true
    Write-Log "Disconnected."
})

# ================== RESTART SERVICE ==================
$btnRestartService.Add_Click({

    $confirm = [System.Windows.MessageBox]::Show(
        "This will restart Azure AD Connect services on THIS machine.`nContinue?",
        "Confirm Service Restart",
        "YesNo",
        "Warning"
    )

    if ($confirm -ne "Yes") { return }

    Write-Log "Restarting Microsoft Azure AD Connect services locally..."
    foreach ($svc in @("ADSync","AADConnectAgentUpdater")) {
        try {
            Set-Service -Name $svc -StartupType Automatic
            Restart-Service -Name $svc -Force
            Write-Log "Service $svc restarted successfully."
        }
        catch {
            Write-Log "Failed to restart $svc : $_"
        }
    }
})

# ================== VIEW INSTRUCTIONS ==================
$btnViewInstructions.Add_Click({
    $w = New-Object System.Windows.Window
    $w.Title = "Script Instructions (Required)"
    $w.SizeToContent = "WidthAndHeight"
    $w.WindowStartupLocation = "CenterScreen"
    $w.ResizeMode = "NoResize"

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = 20

    $gridInstructions = New-Object System.Windows.Controls.Grid
    $gridInstructions.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $gridInstructions.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $gridInstructions.Width = 450

    $txtLeft = New-Object System.Windows.Controls.TextBlock
    $txtLeft.TextWrapping = "Wrap"
    $txtLeft.Margin = "0,0,10,0"
    $txtLeft.Text = @"
PURPOSE OF THIS SCRIPT
----------------------
This dashboard is used to remotely manage Microsoft Entra ID (Azure AD) Connect synchronization operations on a predefined remote server.

It allows authorized administrators to safely perform directory sync actions without logging directly into the Entra Connect server.

REMOTE OPERATION NOTICE
-----------------------
All Sync and Export actions are executed REMOTELY on the target server: $($global:RemoteComputer)

Only the 'Restart Service (Local)' button affects THIS local machine.

BUTTON FUNCTIONS
----------------
FULL IMPORT
Runs a full import cycle on the remote Entra Connect server. Use this when source data changes require a complete re-evaluation.

DELTA IMPORT
Runs a delta import on the remote server. Use this for normal, incremental directory changes.

FULL SYNC
Triggers a full synchronization cycle remotely. Use this when synchronization rules or major changes were made.
"@

    $txtRight = New-Object System.Windows.Controls.TextBlock
    $txtRight.TextWrapping = "Wrap"
    $txtRight.Text = @"
DELTA SYNC
Triggers a delta (incremental) synchronization remotely. This is the most common day-to-day sync operation.

EXPORT
Exports all pending synchronization changes from the remote server to Microsoft Entra ID.

CONNECT USER
Prompts once for administrative credentials and establishes a secure remote PowerShell session to the Entra Connect server.

DISCONNECT USER
Safely closes the remote session and clears stored credentials.

RESTART SERVICE (LOCAL)
Restarts Azure AD Connect services on THIS LOCAL MACHINE ONLY. This does NOT restart services on the remote server.

SAFETY NOTES
------------
• Credentials are requested once and reused securely
• Sync buttons are disabled unless connected
• Local services are never restarted remotely
• Always disconnect when finished

By clicking 'I Have Read and Understand', you acknowledge that you understand
the purpose and scope of this script and will use it responsibly.
"@

    [System.Windows.Controls.Grid]::SetColumn($txtLeft,0)
    [System.Windows.Controls.Grid]::SetColumn($txtRight,1)
    $gridInstructions.Children.Add($txtLeft)
    $gridInstructions.Children.Add($txtRight)

    $stack.Children.Add($gridInstructions)

    $ack = New-Object System.Windows.Controls.Button
    $ack.Content = "I Have Read and Understand"
    $ack.Width = 260
    $ack.Margin = "0,15,0,0"
    $ack.HorizontalAlignment = "Center"
    $ack.Add_Click({
        $global:InstructionsViewed = $true
        $btnConnect.IsEnabled = $true
        $btnRestartService.IsEnabled = $true
        $w.Close()
    })

    $stack.Children.Add($ack)
    $w.Content = $stack
    $w.ShowDialog() | Out-Null
})

# ================== SHOW WINDOW ==================
$window.Content = $grid
$window.ShowDialog() | Out-Null
