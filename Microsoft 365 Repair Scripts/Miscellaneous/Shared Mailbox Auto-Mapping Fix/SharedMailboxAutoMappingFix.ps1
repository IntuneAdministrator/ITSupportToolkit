<#
.SYNOPSIS
    Outlook Shared Mailbox Auto-Mapping Fix (GUI + Exchange Online)

.AUTHOR
    Name        : Allester Padovani
    Title       : Microsoft Intune Engineer
    Script Ver. : 1.0
    Date        : 01.26.2026
#>

# ================== ADMIN CHECK ==================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process powershell.exe `
        -Verb RunAs `
        -WindowStyle Hidden `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ================== INITIAL SETUP ==================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

# ================== MODULE CHECK ==================
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module ExchangeOnlineManagement -Force -Scope AllUsers
}
Import-Module ExchangeOnlineManagement -ErrorAction Stop

# ================== GLOBAL STATE ==================
$script:ExchangeConnected   = $false
$script:InstructionsViewed = $false

# ================== INSTRUCTIONS TEXT ==================
$instructions = @"
HOW IT WORKS:

1. View and acknowledge these instructions (required)
2. Click 'Connect to Exchange Online' and complete sign-in
2. Enter the Shared Mailbox and User
3. Click 'Apply Auto-Mapping Fix'
4. Rebuild the user's Outlook profile after completion
5. Repair Ticket Reference # 2453723

WHAT THE SCRIPT DOES:

- Removes existing FullAccess permission for the user.
- Re-adds FullAccess permission with AutoMapping set to OFF.
- Prevents Outlook from auto-mapping the mailbox and creating a large OST.
- User still retains access but must add the mailbox manually in Outlook.

DATA SAFETY (IMPORTANT):

- NO emails, folders, attachments, or files are deleted.
- NO OST files are deleted or modified.
- NO mailbox data is modified.
- Only changes mailbox permissions and Outlook behavior.

WHAT HAPPENS IF IT DOES NOT SUCCEED:

- A red error GUI will appear showing the reason.
- Common causes:
  * Shared mailbox or user is incorrect.
  * Admin does not have Exchange permissions.
  * User does not currently have FullAccess.
  * Exchange Online session was interrupted.
"@

# ================== ENABLE BUTTONS ==================
function Enable-Buttons {
    if ($script:InstructionsViewed) {
        $connectBtn.IsEnabled    = $true
        $fixBtn.IsEnabled        = $true
        $disconnectBtn.IsEnabled = $true
    }
}

# ================== INSTRUCTIONS WINDOW ==================
function Show-InstructionsGUI {

    $w = New-Object System.Windows.Window
    $w.Title = "Script Instructions (Required)"
    $w.SizeToContent = "WidthAndHeight"
    $w.WindowStartupLocation = "CenterScreen"
    $w.ResizeMode = "NoResize"

    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Margin = 20

    $header = New-Object System.Windows.Controls.TextBlock
    $header.Text = "Please review before proceeding"
    $header.FontSize = 16
    $header.FontWeight = "Bold"
    $header.HorizontalAlignment = "Center"
    $header.Margin = "0,0,0,10"

    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $instructions
    $text.Width = 450
    $text.TextWrapping = "Wrap"
    $text.Margin = "0,0,0,15"

    $ackBtn = New-Object System.Windows.Controls.Button
    $ackBtn.Content = "I Have Read and Understand"
    $ackBtn.Width = 260
    $ackBtn.HorizontalAlignment = "Center"
    $ackBtn.Add_Click({
        $script:InstructionsViewed = $true
        Enable-Buttons
        $w.Close()
    })

    $stack.Children.Add($header) | Out-Null
    $stack.Children.Add($text)   | Out-Null
    $stack.Children.Add($ackBtn) | Out-Null

    $w.Content = $stack
    $w.ShowDialog() | Out-Null
}

# ================== EXCHANGE CONNECT ==================
function Connect-ToExchangeOnlineGUI {
    try {
        $window.WindowState = "Minimized"
        Connect-ExchangeOnline -ShowBanner:$false
        $script:ExchangeConnected = $true
        $statusText.Text = "Status: Connected"
        $statusText.Foreground = "Green"
    }
    catch {
        Show-ErrorGUI -ErrorMessage $_.Exception.Message
    }
    finally {
        $window.WindowState = "Normal"
    }
}

# ================== DISCONNECT ==================
function Disconnect-FromExchangeOnlineGUI {
    Disconnect-ExchangeOnline -Confirm:$false
    $script:ExchangeConnected = $false
    $statusText.Text = "Status: Disconnected"
    $statusText.Foreground = "Red"
}

# ================== ERROR ==================
function Show-ErrorGUI {
    param ([string]$ErrorMessage)
    [System.Windows.MessageBox]::Show(
        $ErrorMessage,
        "Operation Failed",
        "OK",
        "Error"
    ) | Out-Null
}

# ================== APPLY FIX ==================
function Apply-AutoMappingFix {

    if (-not $script:ExchangeConnected) {
        [System.Windows.MessageBox]::Show("Connect to Exchange Online first.") | Out-Null
        return
    }

    $mailbox = $mailboxBox.Text.Trim()
    $user    = $userBox.Text.Trim()

    if (-not $mailbox -or -not $user) {
        [System.Windows.MessageBox]::Show("Both required fields must be completed.") | Out-Null
        return
    }

    try {
        Remove-MailboxPermission -Identity $mailbox -User $user -AccessRights FullAccess -Confirm:$false
        Start-Sleep 2
        Add-MailboxPermission -Identity $mailbox -User $user -AccessRights FullAccess -AutoMapping $false

        [System.Windows.MessageBox]::Show(
            "Auto-Mapping fix applied successfully.`nRebuild Outlook profile.",
            "Completed",
            "OK",
            "Information"
        ) | Out-Null
    }
    catch {
        Show-ErrorGUI -ErrorMessage $_.Exception.Message
    }
}

# ================== BUILD GUI ==================
$window = New-Object System.Windows.Window
$window.Title = "Exchange Online - Shared Mailbox Auto-Mapping Fix"
$window.SizeToContent = "WidthAndHeight"
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "NoResize"

$stack = New-Object System.Windows.Controls.StackPanel
$stack.Margin = 20

$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Shared Mailbox Auto-Mapping Fix"
$header.FontSize = 18
$header.FontWeight = "Bold"
$header.HorizontalAlignment = "Center"
$header.Margin = "0,0,0,10"

$statusText = New-Object System.Windows.Controls.TextBlock
$statusText.Text = "Status: Not Connected"
$statusText.Foreground = "Red"
$statusText.HorizontalAlignment = "Center"
$statusText.Margin = "0,0,0,15"

# Shared Mailbox label
$mailboxLabelPanel = New-Object System.Windows.Controls.StackPanel
$mailboxLabelPanel.Orientation = "Horizontal"
$mailboxLabelPanel.Margin = "0,0,0,5"

$mailboxLabel = New-Object System.Windows.Controls.TextBlock
$mailboxLabel.Text = "Shared Mailbox (email or alias)"

$mailboxAsterisk = New-Object System.Windows.Controls.TextBlock
$mailboxAsterisk.Text = "*"
$mailboxAsterisk.Foreground = "Red"
$mailboxAsterisk.Margin = "5,0,0,0"

$mailboxLabelPanel.Children.Add($mailboxLabel)    | Out-Null
$mailboxLabelPanel.Children.Add($mailboxAsterisk) | Out-Null

$mailboxBox = New-Object System.Windows.Controls.TextBox
$mailboxBox.Width = 350
$mailboxBox.Margin = "0,0,0,15"

# User label
$userLabelPanel = New-Object System.Windows.Controls.StackPanel
$userLabelPanel.Orientation = "Horizontal"
$userLabelPanel.Margin = "0,0,0,5"

$userLabel = New-Object System.Windows.Controls.TextBlock
$userLabel.Text = "User (email or UPN)"

$userAsterisk = New-Object System.Windows.Controls.TextBlock
$userAsterisk.Text = "*"
$userAsterisk.Foreground = "Red"
$userAsterisk.Margin = "5,0,0,0"

$userLabelPanel.Children.Add($userLabel)    | Out-Null
$userLabelPanel.Children.Add($userAsterisk) | Out-Null

$userBox = New-Object System.Windows.Controls.TextBox
$userBox.Width = 350
$userBox.Margin = "0,0,0,20"

# Buttons
$viewInstrBtn = New-Object System.Windows.Controls.Button
$viewInstrBtn.Content = "View Script Instructions (Required)"
$viewInstrBtn.Width = 260
$viewInstrBtn.Margin = "0,0,0,10"
$viewInstrBtn.Add_Click({ Show-InstructionsGUI })

$connectBtn = New-Object System.Windows.Controls.Button
$connectBtn.Content = "Connect to Exchange Online"
$connectBtn.Width = 260
$connectBtn.Margin = "0,0,0,10"
$connectBtn.IsEnabled = $false
$connectBtn.Add_Click({ Connect-ToExchangeOnlineGUI })

$fixBtn = New-Object System.Windows.Controls.Button
$fixBtn.Content = "Apply Auto-Mapping Fix"
$fixBtn.Width = 260
$fixBtn.Margin = "0,0,0,10"
$fixBtn.IsEnabled = $false
$fixBtn.Add_Click({ Apply-AutoMappingFix })

$disconnectBtn = New-Object System.Windows.Controls.Button
$disconnectBtn.Content = "Disconnect from Exchange Online"
$disconnectBtn.Width = 260
$disconnectBtn.Margin = "0,0,0,10"
$disconnectBtn.IsEnabled = $false
$disconnectBtn.Add_Click({ Disconnect-FromExchangeOnlineGUI })

# Add controls
$stack.Children.Add($header) | Out-Null
$stack.Children.Add($statusText) | Out-Null
$stack.Children.Add($viewInstrBtn) | Out-Null
$stack.Children.Add($mailboxLabelPanel) | Out-Null
$stack.Children.Add($mailboxBox) | Out-Null
$stack.Children.Add($userLabelPanel) | Out-Null
$stack.Children.Add($userBox) | Out-Null
$stack.Children.Add($connectBtn) | Out-Null
$stack.Children.Add($fixBtn) | Out-Null
$stack.Children.Add($disconnectBtn) | Out-Null

# ================== COPYRIGHT FOOTER ==================
$footerPanel = New-Object System.Windows.Controls.StackPanel
$footerPanel.Orientation = "Horizontal"
$footerPanel.HorizontalAlignment = "Center"
$footerPanel.Margin = "20,10,20,0"

$copyrightTextBlock = New-Object System.Windows.Controls.TextBlock
$copyrightTextBlock.Text = "Copyright " + [char]169 + " 2026 Allester Padovani | Microsoft Intune Engineer"
$copyrightTextBlock.FontFamily = 'Segoe UI'
$copyrightTextBlock.FontSize = 12
$copyrightTextBlock.HorizontalAlignment = 'Center'
$copyrightTextBlock.VerticalAlignment = 'Center'

$footerPanel.Children.Add($copyrightTextBlock) | Out-Null

# Add footer to main stack
$stack.Children.Add($footerPanel) | Out-Null

$window.Content = $stack
$window.ShowDialog() | Out-Null
