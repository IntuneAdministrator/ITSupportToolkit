<#
.SYNOPSIS
    Displays system information in a styled WPF GUI.

.DESCRIPTION
    This PowerShell script creates a graphical interface (GUI) that allows users to scan and display detailed system information, such as OS name, version, build number, architecture, CPU, memory, and BIOS details. The interface includes a "Start Scan" button, progress bar, status label, and a message box that shows the results.

    The user interface is designed to be clean and modern, with a progress bar and status text to guide the user during the scan. Once the scan is complete, detailed system information is displayed in a message box. This tool is intended for IT specialists and users who need to quickly gather key system data.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 10 and Windows 11

    Requirements :
        - Administrator privileges to access system information.
        - PowerShell 7+ or newer.
        - .NET Framework (for WPF and Windows Forms support).

    Compatibility: Windows 10 and Windows 11

    The script retrieves the following system information:
        - Computer Name
        - OS Name, Version, and Build Number
        - OS Architecture (32-bit or 64-bit)
        - Manufacturer and Model of the system
        - Processor details (CPU)
        - Number of logical processors
        - Total physical memory (RAM)
        - BIOS Manufacturer and Version

    The information is displayed in a message box after the scan completes, and the GUI provides a visual progress bar during the scanning process.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load required assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define XAML UI (matching Outlook Cache Cleaner layout)
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='System Info Tool'
        Height='460' Width='460'
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
        <TextBlock Text='System Info Tool' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='StartScanButton' Content='Start Scan'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Click "Start Scan" to begin.' FontSize='12' Foreground='black' Margin='0,0,0,10'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Reference named elements
$button     = $window.FindName("StartScanButton")
$progress   = $window.FindName("ProgressBar")
$status     = $window.FindName("StatusText")

# Function: Animate progress and show system info
$button.Add_Click({
    $button.IsEnabled = $false
    $status.Text = "Scanning..."
    for ($i = 0; $i -le 100; $i += 5) {
        $progress.Value = $i
        Start-Sleep -Milliseconds 100
        [System.Windows.Forms.Application]::DoEvents()
    }

    try {
        $info = Get-ComputerInfo | Select-Object `
            CsName, OsName, OsVersion, WindowsVersion, OsBuildNumber, OsArchitecture,
            CsManufacturer, CsModel, CsNumberOfLogicalProcessors, CsTotalPhysicalMemory,
            BiosManufacturer, BiosVersion

        $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Name).Trim()
        $mem = [math]::Round($info.CsTotalPhysicalMemory / 1GB, 2)

        $report = @"
System Information:

Computer Name     : $($info.CsName)
OS Name           : $($info.OsName)
OS Version        : $($info.OsVersion)
Windows Version   : $($info.WindowsVersion)
Build Number      : $($info.OsBuildNumber)
Architecture      : $($info.OsArchitecture)

Manufacturer      : $($info.CsManufacturer)
Model             : $($info.CsModel)
Processor         : $cpu
Logical Cores     : $($info.CsNumberOfLogicalProcessors)
Memory Installed  : $mem GB

BIOS Manufacturer : $($info.BiosManufacturer)
BIOS Version      : $($info.BiosVersion -join ", ")
"@

        [System.Windows.Forms.MessageBox]::Show($report, "System Info", 'OK', 'Information')
        $status.Text = "Scan complete. Click again to re-scan."
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", "Error", 'OK', 'Error')
        $status.Text = "Error during scan."
    } finally {
        $progress.Value = 0
        $button.IsEnabled = $true
    }
})

# Show the window
$window.ShowDialog() | Out-Null
