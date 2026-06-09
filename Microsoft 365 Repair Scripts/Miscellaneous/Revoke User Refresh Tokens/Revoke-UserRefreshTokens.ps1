<#
.SYNOPSIS
    Microsoft 365 – Reset User Sign-In Tokens (GUI)

.DESCRIPTION
    Allows an admin to connect to Microsoft Graph, verify a user exists, 
    and revoke all refresh tokens for that user, forcing a fresh sign-in.
    The GUI prevents token revocation until the admin signs in with proper credentials.
    Supports placeholder email input, logs, and safe workflow.

.AUTHOR
    Name  : Allester Padovani
    Title : Microsoft Intune Engineer
    Ver   : 1.0
    Date  : 02.02.2026
#>

# ============================================================
# Microsoft Graph PowerShell Script – Reset User Sign-In Tokens
# ============================================================
# Purpose:
# For a single user experiencing repeated Outlook sign-in prompts,
# this script will connect to Microsoft Graph, verify the user exists,
# and revoke all refresh tokens so the user must sign in fresh.
#
# Why this is needed:
# - Local machine fixes (services, registry, Outlook folders, profiles) may be done already
# - If prompts persist for only one user, the issue is typically:
#     • Stale or corrupted OAuth/Modern Auth tokens in Azure AD / Entra ID
#     • Conditional Access or MFA settings causing repeated login requests
# - Revoking refresh tokens forces Outlook and other M365 apps to request new tokens.
#
# Important Notes:
# - Requires admin credentials for Microsoft 365 / Azure AD
# - Only affects the specified user
# - Local Outlook fixes should be done first
# - After running, the user must **close Outlook, reopen, and sign in once**
# ============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework

# ================== WINDOW ==================
$window = New-Object System.Windows.Window
$window.Title = "Microsoft 365 – Reset User Sign-In Tokens"
$window.SizeToContent = 'WidthAndHeight'
$window.WindowStartupLocation = 'CenterScreen'
$window.ResizeMode = 'CanMinimize'
$window.Background = 'White'

# ================== GRID ==================
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = '10'

0..5 | ForEach-Object { $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) }

# ================== HEADER ==================
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Reset Microsoft 365 User Sign-In Tokens"
$header.FontSize = 16
$header.FontWeight = 'Bold'
$header.HorizontalAlignment = 'Center'
$header.Margin = '0,0,0,10'
[System.Windows.Controls.Grid]::SetRow($header,0)
$grid.Children.Add($header)

# ================== LOG FUNCTION ==================
function Write-Log {
    param($msg)
    $outputBox.Dispatcher.Invoke([action]{
        $outputBox.AppendText("$msg`n")
        $outputBox.ScrollToEnd()
    })
}

# ================== ADMIN SIGN-IN BUTTON ==================
$signInBtn = New-Object System.Windows.Controls.Button
$signInBtn.Content = "Sign in as Admin"
$signInBtn.Width = 180
$signInBtn.Margin = '0,0,0,10'
$signInBtn.HorizontalAlignment = 'Center'
[System.Windows.Controls.Grid]::SetRow($signInBtn,1)
$grid.Children.Add($signInBtn)

# ================== EMAIL INPUT ==================
$emailPanel = New-Object System.Windows.Controls.StackPanel
$emailPanel.Orientation = 'Vertical'
$emailPanel.HorizontalAlignment = 'Center'
$emailPanel.Margin = '0,0,0,10'

$emailLabel = New-Object System.Windows.Controls.Label
$emailLabel.Content = "User Email:"
$emailLabel.FontSize = 14
$emailLabel.FontWeight = 'SemiBold'
$emailLabel.HorizontalAlignment = 'Left'

$emailBox = New-Object System.Windows.Controls.TextBox
$emailBox.Width = 320
$emailBox.Height = 28
$emailBox.FontSize = 13
$emailBox.Padding = '5,2,5,2'
$emailBox.ToolTip = "Enter the email address of the user to reset tokens"

# Placeholder effect
$emailBox.Add_GotFocus({
    if ($emailBox.Text -eq "Type user email here...") {
        $emailBox.Text = ""
        $emailBox.Foreground = [System.Windows.Media.Brushes]::Black
    }
})
$emailBox.Add_LostFocus({
    if ([string]::IsNullOrWhiteSpace($emailBox.Text)) {
        $emailBox.Text = "Type user email here..."
        $emailBox.Foreground = [System.Windows.Media.Brushes]::Gray
    }
})
$emailBox.Text = "Type user email here..."
$emailBox.Foreground = [System.Windows.Media.Brushes]::Gray

# Disabled until admin signs in
$emailBox.IsEnabled = $false

$emailPanel.Children.Add($emailLabel)
$emailPanel.Children.Add($emailBox)
[System.Windows.Controls.Grid]::SetRow($emailPanel,2)
$grid.Children.Add($emailPanel)

# ================== OUTPUT ==================
$outputBox = New-Object System.Windows.Controls.TextBox
$outputBox.FontFamily = 'Consolas'
$outputBox.FontSize = 12
$outputBox.IsReadOnly = $true
$outputBox.AcceptsReturn = $true
$outputBox.TextWrapping = 'Wrap'
$outputBox.VerticalScrollBarVisibility = 'Auto'
$outputBox.MinWidth = 480
$outputBox.MinHeight = 180
$outputBox.Text = "Ready..."
[System.Windows.Controls.Grid]::SetRow($outputBox,3)
$grid.Children.Add($outputBox)

# ================== REVOKE BUTTON ==================
$runBtn = New-Object System.Windows.Controls.Button
$runBtn.Content = "Revoke Sign-In Tokens"
$runBtn.Width = 220
$runBtn.Margin = '10'
$runBtn.HorizontalAlignment = 'Center'
$runBtn.IsEnabled = $false  # Disabled until admin logs in
[System.Windows.Controls.Grid]::SetRow($runBtn,4)
$grid.Children.Add($runBtn)

# Enter key triggers revoke button
$emailBox.Add_KeyDown({
    param($sender,$e)
    if ($e.Key -eq "Enter" -and $runBtn.IsEnabled) {
        $runBtn.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
    }
})

# ================== ADMIN SIGN-IN LOGIC ==================
$signInBtn.Add_Click({
    try {
        Write-Log "Signing in to Microsoft Graph..."
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
            Write-Log "Installing Microsoft.Graph module..."
            Install-Module Microsoft.Graph -Scope CurrentUser -Force
        }

        Connect-MgGraph -Scopes "User.ReadWrite.All" | Out-Null
        Write-Log "Admin signed in successfully."

        # Enable email input and revoke button
        $emailBox.IsEnabled = $true
        $runBtn.IsEnabled = $true

        # Disable sign-in button
        $signInBtn.IsEnabled = $false
    } catch {
        Write-Log "Error signing in: $($_.Exception.Message)"
    }
})

# ================== REVOKE BUTTON LOGIC ==================
$runBtn.Add_Click({
    $email = $emailBox.Text.Trim()
    if (-not $email -or $email -eq "Type user email here..." -or $email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        Write-Log "Please enter a valid email address."
        return
    }

    $runBtn.IsEnabled = $false
    try {
        Write-Log "Looking up user $email ..."
        $user = Get-MgUser -UserId $email -ErrorAction Stop
        Write-Log "User found: $($user.DisplayName)"

        Write-Log "Revoking refresh tokens..."
        Revoke-MgUserSignInSession -UserId $email
        Write-Log "Token revocation completed."
        Write-Log "Ask the user to close Outlook and sign in again."
    } catch {
        Write-Log "ERROR: $($_.Exception.Message)"
    }
    $runBtn.IsEnabled = $true
})

# ================== FOOTER ==================
$footer = New-Object System.Windows.Controls.Label
$footer.Content = "© 2026 Allester Padovani | Microsoft Intune Engineer"
$footer.HorizontalAlignment = 'Center'
$footer.Margin = '0,10,0,0'
[System.Windows.Controls.Grid]::SetRow($footer,5)
$grid.Children.Add($footer)

# ================== SHOW WINDOW ==================
$window.Content = $grid
$window.ShowDialog() | Out-Null
