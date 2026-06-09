<#
.SYNOPSIS
    Wi-Fi Password Dashboard GUI displaying locally saved Wi-Fi profiles.

.DESCRIPTION
    Displays SSID, Authentication, Encryption, and Wi-Fi Password.
    Auto-sizing columns with clean WPF rendering and centered buttons.

.AUTHOR
    Name        : Allester Padovani
    Title       : Microsoft Intune Engineer
    Script Ver. : 1.0
    Date        : 01.16.2026
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# ================== ADMIN CHECK ==================
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ================== WINDOW ==================
$window = New-Object System.Windows.Window
$window.Title = "Wi-Fi Password Dashboard"
$window.SizeToContent = 'WidthAndHeight'
$window.ResizeMode = 'CanMinimize'
$window.WindowStartupLocation = 'CenterScreen'
$window.Background = 'White'

# ================== GRID ==================
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = '10'
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Header
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # DataGrid
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Footer

# ================== HEADER ==================
$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "Wi-Fi Password Dashboard"
$header.FontSize = 16
$header.FontWeight = 'Bold'
$header.HorizontalAlignment = 'Center'
$header.Margin = '0,0,0,10'
[System.Windows.Controls.Grid]::SetRow($header,0)
$grid.Children.Add($header)

# ================== DATAGRID ==================
$dataGrid = New-Object System.Windows.Controls.DataGrid
$dataGrid.AutoGenerateColumns = $false
$dataGrid.IsReadOnly = $true
$dataGrid.HeadersVisibility = 'Column'
$dataGrid.RowHeaderWidth = 0
$dataGrid.HorizontalAlignment = 'Stretch'
$dataGrid.SelectionMode = 'Single'
$dataGrid.SelectionUnit = 'FullRow'

function Add-Column {
    param ($Header, $Binding)

    $col = New-Object System.Windows.Controls.DataGridTextColumn
    $col.Header = $Header
    $col.Binding = New-Object System.Windows.Data.Binding($Binding)
    $col.Width = [System.Windows.Controls.DataGridLength]::Auto
    $col.MinWidth = 140
    $dataGrid.Columns.Add($col)
}

Add-Column "Wi-Fi Name (SSID)" "SSID"
Add-Column "Authentication"   "Authentication"
Add-Column "Encryption"       "Encryption"
Add-Column "Wi-Fi Password"   "Password"

$scroll = New-Object System.Windows.Controls.ScrollViewer
$scroll.Content = $dataGrid
$scroll.HorizontalScrollBarVisibility = 'Auto'
$scroll.VerticalScrollBarVisibility = 'Auto'
[System.Windows.Controls.Grid]::SetRow($scroll,1)
$grid.Children.Add($scroll)

# ================== FOOTER ==================
$footer = New-Object System.Windows.Controls.Grid
$footer.Margin = '10'
$footer.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Buttons row
$footer.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Copyright row

# ----- Button Panel -----
$buttonPanel = New-Object System.Windows.Controls.StackPanel
$buttonPanel.Orientation = 'Horizontal'
$buttonPanel.HorizontalAlignment = 'Center'
$buttonPanel.VerticalAlignment = 'Center'
$buttonPanel.Margin = '0,0,0,5'

$copyBtn = New-Object System.Windows.Controls.Button
$copyBtn.Content = "Copy All Wi-Fi Profiles"
$copyBtn.Width = 200
$copyBtn.Margin = '5,0,5,0'
$copyBtn.Add_Click({ Copy-WiFi })
$buttonPanel.Children.Add($copyBtn)

$refreshBtn = New-Object System.Windows.Controls.Button
$refreshBtn.Content = "Refresh Wi-Fi List"
$refreshBtn.Width = 180
$refreshBtn.Margin = '5,0,5,0'
$refreshBtn.Add_Click({ Refresh-WiFi })
$buttonPanel.Children.Add($refreshBtn)

[System.Windows.Controls.Grid]::SetRow($buttonPanel,0)
$footer.Children.Add($buttonPanel)

# ----- Copyright -----
$copyrightTextBlock = New-Object System.Windows.Controls.Label
$copyrightTextBlock.Content = "Copyright " + [char]169 + " 2026 Allester Padovani | Microsoft Intune Engineer"
$copyrightTextBlock.FontFamily = 'Segoe UI'
$copyrightTextBlock.HorizontalAlignment = 'Center'
$copyrightTextBlock.VerticalAlignment = 'Center'
[System.Windows.Controls.Grid]::SetRow($copyrightTextBlock,1)
$footer.Children.Add($copyrightTextBlock)

[System.Windows.Controls.Grid]::SetRow($footer,2)
$grid.Children.Add($footer)

# ================== DATA FUNCTION ==================
function Refresh-WiFi {

    $profiles = netsh wlan show profiles |
        Select-String "All User Profile" |
        ForEach-Object { ($_ -split ":",2)[1].Trim() }

    $list = @(
        foreach ($ssid in $profiles) {

            $detail = netsh wlan show profile name="$ssid" key=clear

            $authLine = $detail | Select-String "Authentication\s*:" | Select-Object -First 1
            $encLine  = $detail | Select-String "Cipher\s*:" | Select-Object -First 1
            $keyLine  = $detail | Select-String "Key Content\s*:" | Select-Object -First 1

            $auth = if ($authLine) { $authLine.Line -replace '.*:\s*','' } else { "Enterprise / Unknown" }
            $enc  = if ($encLine)  { $encLine.Line -replace '.*:\s*','' }  else { "Enterprise / Unknown" }

            $pwd = if ($keyLine) { $keyLine.Line -replace '.*:\s*','' } 
                   elseif (-not $IsAdmin) { "Run as Administrator" } 
                   else { "Not Stored (Enterprise)" }

            [PSCustomObject]@{
                SSID           = $ssid
                Authentication = $auth
                Encryption     = $enc
                Password       = $pwd
            }
        }
    )

    if ($list.Count -eq 0) {
        $list = @(
            [PSCustomObject]@{
                SSID           = "No Wi-Fi Profiles Found"
                Authentication = "-"
                Encryption     = "-"
                Password       = "-"
            }
        )
    }

    $dataGrid.ItemsSource = $list
}

# ================== COPY FUNCTION ==================
function Copy-WiFi {
    if (-not $dataGrid.ItemsSource) { return }

    $text = ""
    foreach ($i in $dataGrid.ItemsSource) {
        $text += @"
SSID: $($i.SSID)
Authentication: $($i.Authentication)
Encryption: $($i.Encryption)
Password: $($i.Password)
-------------------------
"@
    }

    [System.Windows.Forms.Clipboard]::SetText($text)
}

# ================== START ==================
Refresh-WiFi
$window.Content = $grid
$window.ShowDialog() | Out-Null
exit
