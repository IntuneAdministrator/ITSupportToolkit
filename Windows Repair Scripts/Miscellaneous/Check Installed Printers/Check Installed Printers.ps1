<# 
.SYNOPSIS
    Printer Dashboard GUI displaying physical printers only.

.DESCRIPTION
    This script displays a dashboard showing Printer Name, Driver, Port, IP Address, and Registry Path.
    The script ensures no network scanning or WSD IP guessing.
    It accurately identifies printers where the IP is not exposed (e.g., WSD printers).
    
    Intune-safe: No network scanning or WSD IP guessing. This script runs locally and does not require network-level queries.
    
.AUTHOR
    Name        : Allester Padovani
    Title       : Microsoft Intune Engineer
    Script Ver. : 1.0
    Date        : 01.14.2026
#>

# ================== Initial Setup ==================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load required assemblies for the GUI
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# ================== LOGGING FUNCTION ==================
function Log-Action {
    param (
        [string]$message
    )
    
    $logName = "Application"
    $source = "PowerShell - Printer Dashboard"
    
    # Check if the event log source exists, if not, create it
    if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
        try {
            New-EventLog -LogName $logName -Source $source
        } catch {
            Write-Warning "Run as Administrator to create event log source."
        }
    }
    
    # Log the action to the event log
    Write-EventLog -LogName $logName -Source $source -EntryType Information -EventId 1000 -Message $message
}

# ================== CREATE MAIN WINDOW ==================
$window = New-Object System.Windows.Window
$window.Title = "Printer Dashboard"
$window.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
$window.ResizeMode = [System.Windows.ResizeMode]::CanMinimize
$window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
$window.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::White)
$window.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::Black)

# ================== CREATE WINDOW EVENT HANDLERS ==================
$window.Add_Closing({
    # Ensure the window closes smoothly without interruptions
    Write-Host "Window closing..."
})

# ================== CREATE GRID LAYOUT ==================
$grid = New-Object System.Windows.Controls.Grid
$grid.Margin = '10'
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Header
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # DataGrid
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition)) # Footer

# ================== HEADER ==================
$textBlockHeader = New-Object System.Windows.Controls.TextBlock
$textBlockHeader.Text = "Printer Dashboard"
$textBlockHeader.FontSize = 16
$textBlockHeader.FontWeight = [System.Windows.FontWeights]::Bold
$textBlockHeader.TextAlignment = [System.Windows.TextAlignment]::Center
$textBlockHeader.Margin = [System.Windows.Thickness]::new(0, 0, 0, 20)
[System.Windows.Controls.Grid]::SetRow($textBlockHeader, 0)
[System.Windows.Controls.Grid]::SetColumnSpan($textBlockHeader, 2)
$grid.Children.Add($textBlockHeader)

# ================== DATAGRID ==================
$dataGrid = New-Object System.Windows.Controls.DataGrid
$dataGrid.AutoGenerateColumns = $false
$dataGrid.HeadersVisibility = 'Column'
$dataGrid.CanUserAddRows = $false
$dataGrid.CanUserDeleteRows = $false
$dataGrid.CanUserResizeRows = $false
$dataGrid.RowHeaderWidth = 0
$dataGrid.HorizontalAlignment = 'Stretch'
$dataGrid.VerticalAlignment = 'Stretch'
$dataGrid.IsReadOnly = $true  # Disable editing of rows
$dataGrid.SelectionMode = 'Extended'  # Allow multi-row selection
$dataGrid.SelectionUnit = 'FullRow'  # Optional: Only allows selection of the entire row

# Define columns for the DataGrid
$columnPrinterName = New-Object System.Windows.Controls.DataGridTextColumn
$columnPrinterName.Header = "Printer Name"
$columnPrinterName.Binding = New-Object System.Windows.Data.Binding("PrinterName")
$dataGrid.Columns.Add($columnPrinterName)

$columnDriverName = New-Object System.Windows.Controls.DataGridTextColumn
$columnDriverName.Header = "Driver Name"
$columnDriverName.Binding = New-Object System.Windows.Data.Binding("DriverName")
$dataGrid.Columns.Add($columnDriverName)

$columnPortName = New-Object System.Windows.Controls.DataGridTextColumn
$columnPortName.Header = "Port Name"
$columnPortName.Binding = New-Object System.Windows.Data.Binding("PortName")
$dataGrid.Columns.Add($columnPortName)

$columnPrinterIP = New-Object System.Windows.Controls.DataGridTextColumn
$columnPrinterIP.Header = "Printer IP"
$columnPrinterIP.Binding = New-Object System.Windows.Data.Binding("PrinterIP")
$dataGrid.Columns.Add($columnPrinterIP)

# New Column for Registry Path (but we hide it)
$columnRegistryPath = New-Object System.Windows.Controls.DataGridTextColumn
$columnRegistryPath.Header = "Registry Path"
$columnRegistryPath.Binding = New-Object System.Windows.Data.Binding("RegistryPath")
$columnRegistryPath.Visibility = [System.Windows.Visibility]::Collapsed  # Hide the column
$dataGrid.Columns.Add($columnRegistryPath)

# Add scroll functionality
$scrollViewer = New-Object System.Windows.Controls.ScrollViewer
$scrollViewer.Content = $dataGrid
$scrollViewer.VerticalScrollBarVisibility = 'Auto'
[System.Windows.Controls.Grid]::SetRow($scrollViewer, 1)
[System.Windows.Controls.Grid]::SetColumnSpan($scrollViewer, 2)
$grid.Children.Add($scrollViewer)

# ================== FOOTER PANEL ==================
$footerPanel = New-Object System.Windows.Controls.Grid
$footerPanel.Margin = [System.Windows.Thickness]::new(10)
$footerPanel.HorizontalAlignment = 'Stretch'
$footerPanel.VerticalAlignment = 'Bottom'

# Create 3 columns for the footer: Left (Copyright), Center (Copy button), Right (Refresh button)
$footerPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) # Column 1 (Copyright)
$footerPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) # Column 2 (Copy Button)
$footerPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) # Column 3 (Refresh Button)

# ================== COPYRIGHT LABEL ==================
$copyrightTextBlock = New-Object System.Windows.Controls.Label
$copyrightTextBlock.Content = "Copyright " + [char]169 + " 2026 Allester Padovani | Microsoft Intune Engineer"
$copyrightTextBlock.FontFamily = 'Segoe UI'  # Use a font that supports special characters
$copyrightTextBlock.HorizontalAlignment = 'Left'
$copyrightTextBlock.VerticalAlignment = 'Center'

# Place in the first column (left)
[System.Windows.Controls.Grid]::SetColumn($copyrightTextBlock, 0)
$footerPanel.Children.Add($copyrightTextBlock)

# ================== COPY BUTTON ==================
$copyButton = New-Object System.Windows.Controls.Button
$copyButton.Content = "Copy (Recommended Best Practice)"
$copyButton.Width = 250
$copyButton.Margin = [System.Windows.Thickness]::new(10)
$copyButton.Add_Click({
    Copy-AllPrintersToClipboard
})
$copyButton.HorizontalAlignment = 'Center'
$copyButton.VerticalAlignment = 'Center'

# Place in the second column (center)
[System.Windows.Controls.Grid]::SetColumn($copyButton, 1)
$footerPanel.Children.Add($copyButton)

# ================== REFRESH BUTTON ==================
$refreshButton = New-Object System.Windows.Controls.Button
$refreshButton.Content = "Refresh Printer List"
$refreshButton.Width = 200
$refreshButton.Margin = [System.Windows.Thickness]::new(10)
$refreshButton.Add_Click({
    Refresh-Printers
})
$refreshButton.HorizontalAlignment = 'Right'
$refreshButton.VerticalAlignment = 'Center'

# Place in the third column (right)
[System.Windows.Controls.Grid]::SetColumn($refreshButton, 2)
$footerPanel.Children.Add($refreshButton)

# ================== ADD FOOTER PANEL TO GRID ==================
[System.Windows.Controls.Grid]::SetRow($footerPanel, 2)
[System.Windows.Controls.Grid]::SetColumnSpan($footerPanel, 3)  # Span across the three columns
$grid.Children.Add($footerPanel)

# ================== REFRESH PRINTERS FUNCTION ==================
function Refresh-Printers {
    try {
        # Filter out virtual printers like Microsoft Print to PDF
        $printers = Get-Printer | Where-Object {
            $_.Name -notlike "*Microsoft Print to PDF*" -and
            $_.Name -notlike "*Fax*" -and
            $_.Name -notlike "*Virtual*" -and
            $_.Name -notlike "*XPS*" -and
            $_.Name -notlike "*OneNote*"
        }
    } catch {
        Log-Action "Error fetching printers: $_"
        Write-Host "Error fetching printers. Check the logs for details."
        return
    }

    $printerList = @()
    foreach ($printer in $printers) {
        # Handle registry path accessibility
        try {
            $printerRegistryPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Print\Printers\$($printer.Name)"
            if (Test-Path $printerRegistryPath) {
                $printerRegistryPath = $printerRegistryPath -replace '^HKLM', 'HKEY_LOCAL_MACHINE'
            } else {
                $printerRegistryPath = "Registry path not found"
            }
        } catch {
            $printerRegistryPath = "Access Denied or Path Not Found"
        }

        # Extract printer IP if possible
        $printerIP = 'The Printer is Designed for End-User Self-Installation'
        if ($printer.PortName -match 'IP_') {
            $printerIP = $printer.PortName -replace 'IP_', ''
        }

        $printerObj = New-Object PSObject -property @{
            PrinterName   = $printer.Name
            DriverName    = $printer.DriverName
            PortName      = $printer.PortName
            PrinterIP     = $printerIP
            RegistryPath  = $printerRegistryPath
        }

        $printerList += $printerObj
    }

    # Update the DataGrid with the filtered printer list
    $dataGrid.ItemsSource = $printerList
}

# ================== COPY ALL PRINTERS TO CLIPBOARD ==================
function Copy-AllPrintersToClipboard {
    $allPrinters = $dataGrid.ItemsSource
    if ($allPrinters.Count -gt 0) {
        $formattedText = ""

        # Loop through each printer and format the details
        foreach ($printer in $allPrinters) {
            $formattedText += @"
Printer Name: $($printer.PrinterName)
Driver Name: $($printer.DriverName)
Port Name: $($printer.PortName)
Printer IP: $($printer.PrinterIP)
Registry Path: $($printer.RegistryPath)
----------------------

"@
        }

        # Copy the formatted text to the clipboard
        [System.Windows.Forms.Clipboard]::SetText($formattedText)
        Write-Host "All printer information copied to clipboard."
    } else {
        Write-Host "No printers found to copy."
    }
}

# ================== CALL REFRESH FUNCTION ON STARTUP ==================
Refresh-Printers

# ================== SHOW FORM ==================
$window.Content = $grid
$window.ShowDialog()

exit
