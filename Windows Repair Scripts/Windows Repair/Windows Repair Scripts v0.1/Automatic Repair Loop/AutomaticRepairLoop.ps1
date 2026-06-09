<#
.SYNOPSIS
    This script runs a set of system repair tasks (MBR, CHKDSK, SFC, DISM) on a Windows 11 system, with a graphical user interface (GUI) built using XAML and WPF.

.DESCRIPTION
    This script automates several system repair tasks to help fix common system issues in Windows 11. The script provides a user-friendly GUI for initiating the repair process, which includes:
    - Repairing the Master Boot Record (MBR).
    - Fixing the boot sector.
    - Scanning for Windows installations.
    - Running CHKDSK to check and repair disk errors.
    - Running System File Checker (SFC) to repair corrupted system files.
    - Running DISM (Deployment Imaging Service and Management Tool) to repair system images.
    - It also prompts the user to restart the system after the repair tasks are completed.

    The script requires elevated administrator privileges to execute the repair tasks.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Admin rights to access system event logs and perform system repairs.
        - .NET Framework (for WPF and WinForms) installed on the system.
        - PowerShell 7+ or newer for best compatibility.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# XAML: clean window with one button and a progress bar
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Run System Repair Tasks (Loop) (Windows 11)"
        Height="250" Width="480"
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
            <Setter Property="Margin" Value="10"/>
        </Style>
    </Window.Resources>

    <StackPanel Margin="20" HorizontalAlignment="Center">
        <TextBlock Text="Run System Repair Tasks (Loop) (Windows 11)" 
                   FontSize="16" FontWeight="Bold" Margin="0,10,0,20"
                   HorizontalAlignment="Center"/>
        <Button x:Name="SystemRepairBtn" Content="Start System Repair"/>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="400" Minimum="0" Maximum="7" Margin="0,10,0,10" Value="0"/>
        <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="black"/>
        <TextBlock Text=" Allester Padovani, Senior IT Specialist. All rights reserved." FontSize="12" FontStyle="Italic" Foreground="black" Margin="0,20,0,0" HorizontalAlignment="Center"/>
    </StackPanel>
</Window>
"@

# Load the UI
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$ProgressBar = $window.FindName("ProgressBar")
$StatusText  = $window.FindName("StatusText")

function Show-MessageBox {
    param (
        [string]$message,
        [string]$title = "System Repair",
        [System.Windows.Forms.MessageBoxButtons]$buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($message, $title, $buttons, $icon) | Out-Null
}

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

# Show the window
$window.ShowDialog() | Out-Null
