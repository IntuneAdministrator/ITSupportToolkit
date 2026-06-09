<#
.SYNOPSIS
    A PowerShell GUI tool for system repairs, including DISM/SFC scans, app removals, and more.

.DESCRIPTION
    This script provides a graphical user interface for running various system repair utilities. 
    It includes features such as running DISM and SFC scans to fix system file corruption, 
    cleaning up temporary files, resetting the graphics driver, and removing default Microsoft Store apps.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Admin rights to access system event logs and battery reports.
        - .NET Framework (for WPF and WinForms)
        - PowerShell 7+ or newer
#>

# Ensure script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load required assemblies for WPF UI
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# XAML layout for the GUI window with various buttons
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='System Repair Utility'
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
        <TextBlock Text='System Repair Utility' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        
        <!-- Button for Restarting Print Spooler -->
        <Button x:Name='RestartPrintSpoolerButton' Content='Restart Print Spooler'/>
        
        <!-- Button for Fixing Windows Search -->
        <Button x:Name='FixWindowsSearchButton' Content='Fix Windows Search'/>
        
        <!-- Button for Starting Cleanup -->
        <Button x:Name='StartCleanupButton' Content='Delete Temporary Files'/>
        
        <!-- Button for Cleaning Browser Data -->
        <Button x:Name='CleanBrowserDataButton' Content='Clean Browsing Data'/>
        
        <!-- Button for Resetting Graphics Driver -->
        <Button x:Name='ResetGraphicsDriverButton' Content='Reset Graphics Driver'/>
        
        <!-- Button for Repairing User Profile -->
        <Button x:Name='RepairUserProfileButton' Content='Create Temporary Admin User'/>
        
        <!-- Button for Running DISM and SFC -->
        <Button x:Name='RunRepairButton' Content='Start System Repair (DISM/SFC)'/>

        <!-- Button for Start Repair Tasks -->
        <Button x:Name='SystemRepairBtn' Content='Start System Repair'/>
        
        <!-- Button for Microsoft Store App Removal -->
        <Button x:Name='RemoveAppsBtn' Content='Remove Default Microsoft Store Apps'/>
        
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML for the window
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Define controls from the window
$RestartPrintSpoolerButton = $window.FindName("RestartPrintSpoolerButton")
$FixWindowsSearchButton = $window.FindName("FixWindowsSearchButton")
$StartCleanupButton = $window.FindName("StartCleanupButton")
$CleanBrowserDataButton = $window.FindName("CleanBrowserDataButton")
$ResetGraphicsDriverButton = $window.FindName("ResetGraphicsDriverButton")
$RepairUserProfileButton = $window.FindName("RepairUserProfileButton")
$RunRepairButton = $window.FindName("RunRepairButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Function to update UI elements
function Update-UI {
    [System.Windows.Forms.Application]::DoEvents()
}

# Define paths for DISM and SFC logs
$dismLogFolder = "C:\ProgramData\OzarkTechTeam\DISM tool Logs"
$sfcLogFolder = "C:\ProgramData\OzarkTechTeam\SFC Logs"
$dismLogFile = Join-Path $dismLogFolder "DISM_log.txt"
$sfcLogFile = Join-Path $sfcLogFolder "SFC_log.txt"

if (-not (Test-Path $dismLogFolder)) { New-Item -Path $dismLogFolder -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $sfcLogFolder)) { New-Item -Path $sfcLogFolder -ItemType Directory -Force | Out-Null }

# Function to handle DISM and SFC repair
$RunRepairButton.Add_Click({
    $RunRepairButton.IsEnabled = $false
    $StatusText.Text = "Starting System Repair..."

    # DISM Steps
    $dismSteps = @(
        @{ Description = "Checking image health (DISM)..."; Cmd = { dism.exe /Online /Cleanup-Image /CheckHealth | Out-File -FilePath $dismLogFile -Append }; Progress = 30 },
        @{ Description = "Scanning image health (DISM)..."; Cmd = { dism.exe /Online /Cleanup-Image /ScanHealth | Out-File -FilePath $dismLogFile -Append }; Progress = 60 },
        @{ Description = "Restoring image health (DISM)..."; Cmd = { dism.exe /Online /Cleanup-Image /RestoreHealth | Out-File -FilePath $dismLogFile -Append }; Progress = 100 }
    )

    "Starting DISM tool at $(Get-Date)" | Out-File -FilePath $dismLogFile -Append

    foreach ($step in $dismSteps) {
        $StatusText.Text = "{0} {1}%" -f $step.Description, $step.Progress
        $ProgressBar.Value = $step.Progress
        Update-UI
        try {
            & $step.Cmd
            "$($step.Description) succeeded at $(Get-Date)" | Out-File -FilePath $dismLogFile -Append
        } catch {
            "Error during $($step.Description): $_" | Out-File -FilePath $dismLogFile -Append
        }
    }

    "DISM process completed at $(Get-Date)`r`n" | Out-File -FilePath $dismLogFile -Append

    # SFC Step
    $StatusText.Text = "Starting System File Checker (SFC)..."
    $ProgressBar.Value = 0
    Update-UI

    "Starting SFC at $(Get-Date)" | Out-File -FilePath $sfcLogFile -Append

    try {
        $StatusText.Text = "Running System File Checker (SFC)... 50%"
        $ProgressBar.Value = 50
        Update-UI
        sfc.exe /scannow | Out-File -FilePath $sfcLogFile -Append
        "SFC scan completed at $(Get-Date)" | Out-File -FilePath $sfcLogFile -Append
        $ProgressBar.Value = 100
        $StatusText.Text = "System File Checker (SFC) completed. 100%"
        Update-UI
    } catch {
        "Error during SFC scan: $_" | Out-File -FilePath $sfcLogFile -Append
    }

    $RunRepairButton.IsEnabled = $true
})

# App removal policy button click logic
$window.FindName("RemoveAppsBtn").Add_Click({
    Animate-ProgressBar

    $basePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx\RemoveDefaultMicrosoftStorePackages"
    $packages = @(
        "Clipchamp.Clipchamp_yxz26nhyzhsrt",
        "Microsoft.BingNews_8wekyb3d8bbwe",
        "Microsoft.BingWeather_8wekyb3d8bbwe",
        "Microsoft.GamingApp_8wekyb3d8bbwe",
        "Microsoft.MediaPlayer_8wekyb3d8bbwe",
        "Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe",
        "Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe",
        "Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe",
        "Microsoft.OutlookForWindows_8wekyb3d8bbwe",
        "Microsoft.Paint_8wekyb3d8bbwe",
        "Microsoft.ScreenSketch_8wekyb3d8bbwe",
        "Microsoft.Todos_8wekyb3d8bbwe",
        "Microsoft.Windows.Photos_8wekyb3d8bbwe",
        "Microsoft.WindowsCalculator_8wekyb3d8bbwe",
        "Microsoft.WindowsCamera_8wekyb3d8bbwe",
        "Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe",
        "Microsoft.WindowsNotepad_8wekyb3d8bbwe",
        "Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe",
        "Microsoft.Xbox.TCUI_8wekyb3d8bbwe",
        "Microsoft.XboxGamingOverlay_8wekyb3d8bbwe",
        "Microsoft.XboxIdentityProvider_8wekyb3d8bbwe",
        "Microsoft.XboxSpeechToTextOverlay_8wekyb3d8bbwe",
        "Microsoft.ZuneMusic_8wekyb3d8bbwe",
        "Microsoft.ZuneVideo_8wekyb3d8bbwe",
        "MicrosoftTeams_8wekyb3d8bbwe",
        "7EE7776C.LinkedInforWindows_w1wdnht996qgy",
        "Microsoft.Copilot_8wekyb3d8bbwe"
    )

    if (-not (Test-Path $basePath)) {
        New-Item -Path $basePath -Force | Out-Null
    }

    Set-ItemProperty -Path $basePath -Name "Enabled" -Type DWord -Value 1

    for ($i = 0; $i -lt $packages.Count; $i++) {
        $pkg = $packages[$i]
        $pkgPath = Join-Path $basePath $pkg
        if (-not (Test-Path $pkgPath)) {
            New-Item -Path $pkgPath -Force | Out-Null
        }
        Set-ItemProperty -Path $pkgPath -Name "RemovePackage" -Type DWord -Value 1
        $ProgressBar.Value = [math]::Round(($i + 1) / $packages.Count * 100)
        $StatusText.Text = "Applying App Policy... $($i + 1) of $($packages.Count)"
        [System.Windows.Forms.Application]::DoEvents()
    }

    $ProgressBar.Value = 0
    $StatusText.Text = "Done."
    Show-Result "App Removal" "Policy applied to $($packages.Count) packages."
})

# Function to run a system command
function Run-Command {
    param (
        [string]$command,
        [string]$arguments
    )

    Write-Host "`n[+] Executing: $command $arguments"
    $resolvedCommand = Get-Command $command -ErrorAction SilentlyContinue
    if (-not $resolvedCommand) {
        Show-MessageBox -message "Command '$command' not found. This operation will be skipped." -icon 'Error'
        return
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $resolvedCommand.Source
    $psi.Arguments = $arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.Start() | Out-Null

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($stdout) { Write-Host $stdout }
    if ($stderr) { Write-Host "ERROR: $stderr" -ForegroundColor Red }

    if ($process.ExitCode -ne 0) {
        Show-MessageBox -message "Error running '$command'.`nExit Code: $($process.ExitCode)`nDetails: $stderr" -icon 'Error'
    }
}

# Function to update UI status and progress
function Update-UI {
    param (
        [string]$status,
        [int]$progressValue
    )
    $StatusText.Text = "$status ($([int](($progressValue / $ProgressBar.Maximum) * 100))%)"
    $ProgressBar.Value = $progressValue
    [System.Windows.Forms.Application]::DoEvents()
}

# Button logic
$window.FindName("SystemRepairBtn").Add_Click({
    # Ensure Admin
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Show-MessageBox -message "This script must be run as Administrator." -icon 'Error'
        return
    }

    # Prompt before running
    $result = [System.Windows.Forms.MessageBox]::Show(
        "System repair tasks may take up to 1 hour. Continue?",
        "Confirmation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
        $StatusText.Text = "Cancelled by user."
        return
    }

    $systemDir = [System.Environment]::SystemDirectory
    $isInWinRE = $systemDir -like "X:\*"
    $step = 0

    if ($isInWinRE) {
        $step++
        Update-UI "Repairing MBR..." $step
        Run-Command "bootrec.exe" "/fixmbr"

        $step++
        Update-UI "Fixing Boot Sector..." $step
        Run-Command "bootrec.exe" "/fixboot"

        $step++
        Update-UI "Scanning for Windows Installations..." $step
        Run-Command "bootrec.exe" "/scanos"
    }

    $step++
    Update-UI "Running CHKDSK..." $step
    Run-Command "chkdsk.exe" "/f /r C:"

    $step++
    Update-UI "Running SFC..." $step
    Run-Command "sfc.exe" "/scannow"

    $step++
    Update-UI "Running DISM..." $step
    Run-Command "DISM.exe" "/Online /Cleanup-Image /RestoreHealth"

    Update-UI "All repair tasks completed." $ProgressBar.Maximum
    Show-MessageBox -message "System repair completed. A restart is recommended."

    # Ask for reboot
    $restartPrompt = [System.Windows.Forms.MessageBox]::Show(
        "Would you like to restart your computer now?",
        "Restart Required",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($restartPrompt -eq [System.Windows.Forms.DialogResult]::Yes) {
        Restart-Computer -Force
    } else {
        $StatusText.Text = "Repair complete. Restart pending."
    }
})

# Hook up other existing buttons (e.g., Restart Print Spooler, Fix Windows Search, etc.)

# Show the window with all buttons
[void]$window.ShowDialog()
