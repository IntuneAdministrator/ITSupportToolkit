<#
.SYNOPSIS
    Performs Windows Update repair by stopping services, renaming update folders, and running DISM & SFC tools.

.DESCRIPTION
    This PowerShell script provides a GUI interface to assist in repairing Windows Update functionality. The script stops essential update-related services, renames corrupted update cache folders, and then restarts the services. It runs the DISM (Deployment Imaging Service and Management) tool with the `/CheckHealth`, `/ScanHealth`, and `/RestoreHealth` options, followed by the System File Checker (SFC) tool to ensure system integrity. 

    The script is intended to help troubleshoot and resolve issues with Windows Update by fixing potential corruption in the Windows Update components and system files. The user is provided with step-by-step updates via a progress bar, and a completion message box is displayed once the process is finished.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Administrator rights to manage update services and perform system repairs.
        - PowerShell 7+ or newer.
        - .NET Framework (for WPF and Windows Forms support).
    
    This tool is designed for IT professionals or system administrators who need to resolve issues related to Windows Update.

    The script performs the following functions:
        - Stops and restarts update-related services (`wuauserv`, `cryptSvc`, `bits`, and `msiserver`).
        - Renames potentially corrupted update folders (`SoftwareDistribution` and `catroot2`).
        - Runs the DISM tool with health check, scan, and restore options.
        - Runs System File Checker (SFC) to fix system file integrity issues.
        - Provides a progress bar and user notifications throughout the repair process.
        
    This tool is designed for Windows 10/11 environments with administrative rights.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load necessary assemblies for WPF and Windows Forms
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define the XAML layout for the UI
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Windows Update Repair'
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
        <TextBlock Text='Windows Update Repair' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='RunGpupdateButton' Content='Run Windows Update Repair' />
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML into a Window object
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get named elements
$RunGpupdateButton = $window.FindName("RunGpupdateButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Helper function to update status and progress
function Update-UI {
    param (
        [string]$Message,
        [int]$PercentComplete = $null
    )
    if ($PercentComplete -ne $null) {
        $ProgressBar.Value = $PercentComplete
    }
    $StatusText.Text = $Message
    [System.Windows.Forms.Application]::DoEvents()
}

# Function to perform Windows Update repair
function Run-WindowsUpdateMaintenance {
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
}

# Wire up the button click event
$RunGpupdateButton.Add_Click({
    Run-WindowsUpdateMaintenance
})

# Show the window
$window.ShowDialog()
