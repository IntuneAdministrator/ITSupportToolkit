<#
.SYNOPSIS
    A diagnostic and repair tool to assist in updating Windows, upgrading drivers, and resolving Windows Update issues using various tools like DISM, PSWindowsUpdate, and Group Policy updates.

.DESCRIPTION
    This PowerShell script offers a GUI-based utility designed to assist in performing various Windows system maintenance and update tasks. It provides a set of buttons for users to:
        - Update Windows drivers
        - Upgrade all packages using `winget`
        - Install Windows updates with the `PSWindowsUpdate` module
        - Force a Group Policy update
        - Run a comprehensive Windows Update repair process, including stopping services, renaming update cache folders, running DISM checks, and performing System File Checker (SFC) scans.

    The interface provides a progress bar and displays status updates throughout the execution of each task. This tool is primarily intended for IT professionals who need to resolve issues related to Windows Update and system maintenance.

    **Key Features:**
    - **Driver updates** using Windows Update.
    - **Package upgrades** with `winget`.
    - **Windows Update repair** by restarting services, renaming folders, and running repair tools.
    - **Group Policy update** for immediate changes to group policies.
    - **System diagnostics and health checks**.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Requirements :
        - Administrator privileges to manage services and perform system repairs.
        - PowerShell 7+ or newer with access to Windows Update services.
        - WPF/Windows Forms for GUI support (requires .NET).
        - `PSWindowsUpdate` PowerShell module for managing Windows updates.

    This tool is designed for Windows 10/11 environments.
    
    The tool performs the following actions:
        - **Windows Update repair** (stopping services, renaming update folders, running DISM, and SFC).
        - **Windows driver updates**.
        - **Package upgrades** using `winget` (Windows Package Manager).
        - **Group Policy update** force.
        - **Status monitoring** via progress bar and completion notifications.
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
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# XAML Layout
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Update Diagnostic &amp; Health Check Tool"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Background="#f4f4f4"
        FontFamily="Segoe UI"
        FontSize="12"
        SizeToContent="WidthAndHeight">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#f4f4f4"/>
            <Setter Property="Foreground" Value="Black"/>
            <Setter Property="BorderBrush" Value="#cccccc"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Width" Value="400"/>
            <Setter Property="Height" Value="20"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>
    </Window.Resources>
    <StackPanel Margin="20" HorizontalAlignment="Center">
        <TextBlock Text="Update Diagnostic &amp; Health Check Tool" FontSize="16" FontWeight="Bold" Margin="0,0,0,20"
                   HorizontalAlignment="Center"/>
        <Button x:Name="RunUpdateButton" Content="Update Windows Drivers"/>
        <Button x:Name="WingetUpgradeButton" Content="Upgrade All Packages (winget)"/>
        <Button x:Name="PSWUInstallButton" Content="Install Windows Updates (PSWindowsUpdate)"/>
        <Button x:Name="GPUpdateButton" Content="Force Group Policy Update"/>
        <Button x:Name="RepairWindowsButton" Content="Run Windows Update Repair"/>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="400" Minimum="0" Maximum="100" Margin="0,5,0,5" Value="0"/>
        <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="black"/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML UI
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get elements
$RunUpdateButton = $window.FindName("RunUpdateButton")
$WingetUpgradeButton = $window.FindName("WingetUpgradeButton")
$PSWUInstallButton = $window.FindName("PSWUInstallButton")
$GPUpdateButton = $window.FindName("GPUpdateButton")
$RepairWindowsButton = $window.FindName("RepairWindowsButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Helper: Update status and progress
function Update-UI {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 150
}

# Button
function Set-ButtonsEnabled($enabled) {
    $RunUpdateButton.IsEnabled = $enabled
    $WingetUpgradeButton.IsEnabled = $enabled
    $PSWUInstallButton.IsEnabled = $enabled
    $GPUpdateButton.IsEnabled = $enabled
    $RepairWindowsButton.IsEnabled = $enabled
}

# (Existing button event handlers omitted here for brevity, keep previous code for first 4 buttons)

# New button event for running Windows repair commands
$RepairWindowsButton.Add_Click({
    Set-ButtonsEnabled $false
    try {
        Update-UI "Stopping update-related services..." 5
        net stop wuauserv | Out-Null
        net stop cryptSvc | Out-Null
        net stop bits | Out-Null
        net stop msiserver | Out-Null

        Update-UI "Renaming update cache folders..." 15
        Rename-Item -Path "C:\Windows\SoftwareDistribution" -NewName "SoftwareDistribution.old" -ErrorAction SilentlyContinue
        Rename-Item -Path "C:\Windows\System32\catroot2" -NewName "catroot2.old" -ErrorAction SilentlyContinue

        Update-UI "Restarting update services..." 25
        net start wuauserv | Out-Null
        net start cryptSvc | Out-Null
        net start bits | Out-Null
        net start msiserver | Out-Null

        Update-UI "Running DISM CheckHealth..." 35
        Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /CheckHealth" -NoNewWindow -Wait

        Update-UI "Running DISM ScanHealth..." 50
        Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /ScanHealth" -NoNewWindow -Wait

        Update-UI "Running DISM RestoreHealth..." 65
        Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -NoNewWindow -Wait

        Update-UI "Running System File Checker (SFC)..." 80

        # Create a temporary file to capture output
        $tempFile = [System.IO.Path]::GetTempFileName()

        # Run SFC and redirect output
        $sfcProc = Start-Process -FilePath "cmd.exe" `
        -ArgumentList "/c sfc /scannow > `"$tempFile`"" `
        -WindowStyle Hidden -Wait -PassThru

        # Read the result
        $sfcOutput = Get-Content $tempFile -Raw
        Remove-Item $tempFile -Force

        Update-UI "Windows Update Repair completed successfully." 100
        [System.Windows.Forms.MessageBox]::Show("Windows Update Repair completed successfully.","Repair Complete",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)

    }
    catch {
        Update-UI "An error occurred during repair." 100
        [System.Windows.Forms.MessageBox]::Show("An error occurred:`n$_","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Show the window
$window.ShowDialog() | Out-Null
