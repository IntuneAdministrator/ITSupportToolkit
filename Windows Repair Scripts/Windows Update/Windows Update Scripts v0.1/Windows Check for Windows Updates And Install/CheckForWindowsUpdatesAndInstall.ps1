<#
.SYNOPSIS
    Initiates a Windows Update session through a WPF GUI, downloading and installing available updates.

.DESCRIPTION
    This PowerShell script provides a graphical user interface (GUI) for performing Windows updates on a system. Using the `Microsoft.Update.Session` COM object, it searches for available updates, downloads them, and installs them. The script also tracks the progress and provides feedback to the user through a progress bar and message boxes. If updates are successfully installed, the script notifies the user. If a system restart is required to complete the installation, the user is informed.

    The script checks for administrator privileges and relaunches with elevated rights if necessary. It uses a step-by-step approach, from searching for updates to installing them, with progress updates displayed at each stage.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Administrator rights for performing Windows Update operations.
        - PowerShell 7+ or newer.
        - .NET Framework (for WPF and Windows Forms support).
    
    This tool is intended for IT professionals and system administrators who need to perform and monitor Windows Update processes in an efficient, user-friendly manner.

    The script performs the following functions:
        - Initiates a Windows Update session and searches for available updates.
        - Downloads and installs updates while updating the user on progress.
        - Notifies the user of the success or failure of the update installation.
        - Alerts the user if a restart is required to complete the installation.
        
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

# Load required assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# XAML Layout
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Windows Update'
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
        <TextBlock Text='Windows Update' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='StartUpdateButton' Content='Start Windows Update'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,10,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML UI
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get elements
$StartUpdateButton = $window.FindName("StartUpdateButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Helper: Update status and progress
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

# Button event
$StartUpdateButton.Add_Click({
    try {
        Update-UI "Creating Windows Update session..." 5

        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()

        Update-UI "Searching for available updates..." 15

        $searchResult = $updateSearcher.Search("IsInstalled=0")

        if ($searchResult.Updates.Count -gt 0) {
            $totalUpdates = $searchResult.Updates.Count
            Update-UI "Found $totalUpdates update(s). Preparing to download..." 20

            $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
            $i = 0
            foreach ($update in $searchResult.Updates) {
                $updatesToInstall.Add($update) | Out-Null
                $i++
                $percent = 20 + [Math]::Round(($i / $totalUpdates) * 10)
                Update-UI "Queued update $i of ${totalUpdates}: $($update.Title)" $percent
                Start-Sleep -Milliseconds 200
            }

            $downloader = $updateSession.CreateUpdateDownloader()
            $downloader.Updates = $updatesToInstall
            Update-UI "Downloading updates..." 40

            $downloadResult = $downloader.Download()

            if ($downloadResult.ResultCode -ne 2) {
                throw "Download failed. Result code: $($downloadResult.ResultCode)"
            }

            $installer = $updateSession.CreateUpdateInstaller()
            $installer.Updates = $updatesToInstall
            Update-UI "Installing updates..." 70

            $installResult = $installer.Install()

            if ($installResult.ResultCode -eq 2) {
                Update-UI "All updates installed successfully." 100
                [System.Windows.Forms.MessageBox]::Show("All updates installed successfully.","Success",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
            } else {
                Update-UI "Some updates installed with warnings. Code: $($installResult.ResultCode)" 100
                [System.Windows.Forms.MessageBox]::Show("Some updates installed with warnings. Result code: $($installResult.ResultCode)","Warning",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
            }

            if ($installResult.RebootRequired) {
                Update-UI "A system restart is required to complete installation." 100
                [System.Windows.Forms.MessageBox]::Show("A system restart is required to complete installation.","Restart Required",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
            }

        } else {
            Update-UI "No updates found. System is up to date." 100
            [System.Windows.Forms.MessageBox]::Show("No updates found. System is up to date.","Up to Date",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        Update-UI "Error occurred: $_" 100
        [System.Windows.Forms.MessageBox]::Show("An error occurred:`n$_","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Show window
$window.ShowDialog()
