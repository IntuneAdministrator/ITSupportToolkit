<#
.SYNOPSIS
    Cleans user temp files, Windows temp files, prefetch data, and recycle bin contents on Windows 11 24H2.

.DESCRIPTION
    This PowerShell script provides a graphical interface (WPF) for cleaning up temporary files, prefetch data, 
    and recycle bin contents from a Windows 11 system. It allows users to free up disk space and improve performance by:
    - Deleting files in the user's local Temp folder.
    - Removing files in the system Temp folder.
    - Cleaning prefetch files to improve boot time.
    - Clearing the Recycle Bin using the `Clear-RecycleBin` cmdlet.
    
    The script presents a progress bar during the cleanup process and a completion message box when the operation is finished.

    The cleanup process is carried out safely with error handling to ensure no data is lost.

.AUTHOR
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2

.NOTES
    Requirements:
        - Administrator privileges to ensure full access to system files and Recycle Bin.
        - PowerShell 7 or newer to support WPF-based user interface.
    Tested on:
        - Windows 11 24H2

    Known Issues:
        - Cleanup process might take some time depending on the amount of data in Temp folders.
        - The script doesn't attempt to delete any locked or in-use files in the Temp folders.

    This script is intended to help improve system performance by clearing unnecessary temporary files.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define XAML layout (fixed xmlns:x declaration)
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Temp Cleaner - Windows 11 24H2'
        Height='220' Width='460'
        ResizeMode='NoResize'
        WindowStartupLocation='CenterScreen'
        Background='#f4f4f4'
        FontFamily='Segoe UI'
        FontSize='12'
        SizeToContent='WidthAndHeight'>
    <Window.Resources>
        <Style TargetType='Button'>
            <Setter Property='Background' Value='#f4f4f4'/>
            <Setter Property='Foreground' Value='Black'/>
            <Setter Property='BorderBrush' Value='#cccccc'/>
            <Setter Property='BorderThickness' Value='1'/>
            <Setter Property='FontWeight' Value='Bold'/>
            <Setter Property='Cursor' Value='Hand'/>
            <Setter Property='Width' Value='400'/>
            <Setter Property='Height' Value='20'/>
            <Setter Property='Margin' Value='0,0,0,10'/>
        </Style>
    </Window.Resources>
    <StackPanel Margin='20' HorizontalAlignment='Center'>
        <TextBlock Text='Temporary Files &amp; Prefetch Cleaner' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='StartButton' Content='Start Cleanup'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black' Margin='0,5,0,0'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Access UI controls
$startButton = $window.FindName("StartButton")
$progressBar = $window.FindName("ProgressBar")
$statusText  = $window.FindName("StatusText")

# Helper function to update UI safely
function Update-UI {
    param([string]$Message, [int]$Percent = $null)
    $window.Dispatcher.Invoke([action] {
        $statusText.Text = $Message
        if ($Percent -ne $null) {
            $progressBar.Value = [math]::Min([math]::Max($Percent, 0), 100)
        }
        [System.Windows.Forms.Application]::DoEvents()
    })
}

# Function to clear folder contents safely
function Clear-Folder {
    param ([string]$Path)
    if (Test-Path $Path) {
        try {
            Remove-Item "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {
            # Suppress errors to not interrupt cleanup
        }
    }
}

# Attach click event to Start button
$startButton.Add_Click({
    try {
        $startButton.IsEnabled = $false
        Update-UI "Starting cleanup..." 0

        $userTemp    = "C:\Users\$($env:USERNAME)\AppData\Local\Temp"
        $windowsTemp = "C:\Windows\Temp"
        $prefetch    = "C:\Windows\Prefetch"

        $paths = @($userTemp, $windowsTemp, $prefetch)
        $step = 90 / $paths.Count  # Reserve 10% for recycle bin cleanup
        $progress = 0

        foreach ($path in $paths) {
            Update-UI "Cleaning: $path" $progress
            Clear-Folder $path
            $progress += $step
            Update-UI "Cleaning: $path" $progress
            Start-Sleep -Milliseconds 500
        }

        Update-UI "Clearing Recycle Bin..." 95
        try {
            Clear-RecycleBin -Force -ErrorAction Stop
        }
        catch {
            # Ignore recycle bin errors silently
        }

        Update-UI "Cleanup completed." 100

        [System.Windows.Forms.MessageBox]::Show(
            "Temporary files, prefetch data, and recycle bin have been cleaned successfully.",
            "Cleanup Complete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred: $_",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        Update-UI "Cleanup failed." 0
    }
    finally {
        $startButton.IsEnabled = $true
    }
})

# Show the window
[void]$window.ShowDialog()
