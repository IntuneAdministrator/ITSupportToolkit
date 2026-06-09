<#
.SYNOPSIS
    General Repair Toolbox - A PowerShell-based GUI utility for performing common system repair tasks on Windows.

.DESCRIPTION
    This script provides a user-friendly graphical interface (built with WPF) to perform essential system repair operations 
    such as resetting network adapters, clearing the Windows Store cache, repairing Windows Update, restarting Explorer, 
    clearing browser cache, and running diagnostics like SFC or CHKDSK.

    It is intended for IT professionals and support technicians who need quick access to troubleshooting tools in one place.
    The script checks for administrator privileges and auto-elevates if needed.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Administrator privileges (auto-elevated at runtime)
        - .NET Framework (for WPF and WinForms)
        - PowerShell 7.0 or newer
#>

# Ensure script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load necessary assemblies for WPF
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Define the XAML layout for the UI (without BtnRepairFileAssoc)
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='General Repair Toolbox'
        Height='480' Width='460'
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
        <TextBlock Text='General Repair Toolbox' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>        
        <Button x:Name='BtnNetTroubleshooter' Content='Run Network Troubleshooter'/>
        <Button x:Name='BtnResetNetwork' Content='Reset Network Adapters'/>
        <Button x:Name='BtnClearWSCache' Content='Clear Windows Store Cache'/>
        <Button x:Name='BtnFixWindowsUpdate' Content='Repair Windows Update'/>
        <Button x:Name='BtnCheckDisk' Content='Check Disk for Errors'/>
        <Button x:Name='BtnRestartExplorer' Content='Restart Windows Explorer'/>
        <Button x:Name='BtnClearBrowserCache' Content='Clear Temporary Internet Files'/>
        <Button x:Name='BtnResetPrintQueue' Content='Reset Printer Queue'/>
        <Button x:Name='BtnRunSFC' Content='Run System File Checker (SFC)'/>        
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text=" Allester Padovani, Senior IT Specialist. All rights reserved." FontSize="12" FontStyle="Italic" Foreground="black" Margin="0,20,0,0" HorizontalAlignment="Center"/>
    </StackPanel>
</Window>
"@

# Load XAML into a Window object
[xml]$xamlXml = $xaml
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Find UI elements
$BtnNetTroubleshooter = $window.FindName("BtnNetTroubleshooter")
$BtnResetNetwork = $window.FindName("BtnResetNetwork")
$BtnClearWSCache = $window.FindName("BtnClearWSCache")
$BtnFixWindowsUpdate = $window.FindName("BtnFixWindowsUpdate")
$BtnCheckDisk = $window.FindName("BtnCheckDisk")
$BtnRestartExplorer = $window.FindName("BtnRestartExplorer")
$BtnClearBrowserCache = $window.FindName("BtnClearBrowserCache")
$BtnResetPrintQueue = $window.FindName("BtnResetPrintQueue")
$BtnRunSFC = $window.FindName("BtnRunSFC")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Helper function to update UI safely
function Update-UI {
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

# Update progress bar and status
function Update-Progress {
    param([int]$percent, [string]$message)
    $ProgressBar.Value = $percent
    $StatusText.Text = $message
    Update-UI
}

# Button handlers

# 1. Run Network Troubleshooter
$BtnNetTroubleshooter.Add_Click({
    try {
        Update-Progress -percent 10 -message "Launching Network Troubleshooter..."
        Start-Process "msdt.exe" -ArgumentList "/id NetworkDiagnosticsNetworkAdapter" -WindowStyle Normal
        Update-Progress -percent 100 -message "Network Troubleshooter launched."
        Start-Sleep -Seconds 3
        Update-Progress -percent 0 -message "Ready."
    } catch {
        [System.Windows.MessageBox]::Show("Failed to launch troubleshooter.`n$($_.Exception.Message)","Error",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# 2. Reset Network Adapters (with reboot prompt)
$BtnResetNetwork.Add_Click({
    try {
        Update-Progress -percent 10 -message "Flushing DNS..."
        ipconfig /flushdns | Out-Null
        Start-Sleep -Seconds 1

        Update-Progress -percent 40 -message "Resetting IP stack..."
        netsh int ip reset | Out-Null
        Start-Sleep -Seconds 1

        Update-Progress -percent 70 -message "Resetting Winsock..."
        netsh winsock reset | Out-Null
        Start-Sleep -Seconds 1

        Update-Progress -percent 100 -message "Network adapters reset completed."

        $result = [System.Windows.MessageBox]::Show(
            "Network adapters have been reset successfully.`nWould you like to restart your computer in 2 minutes?",
            "Restart Required",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )

        if ($result -eq "Yes") {
            shutdown.exe /r /t 120 /c "Restarting to complete network adapter reset."
        }

        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to reset network adapters.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# 3. Clear Windows Store Cache
$BtnClearWSCache.Add_Click({
    try {
        Update-Progress -percent 10 -message "Clearing Windows Store cache..."
        Start-Process "wsreset.exe" -WindowStyle Hidden
        Update-Progress -percent 100 -message "Windows Store cache cleared."
        [System.Windows.MessageBox]::Show("Windows Store cache cleared. The Store will now open.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to clear Windows Store cache.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# 4. Repair Windows Update
$BtnFixWindowsUpdate.Add_Click({
    try {
        Update-Progress -percent 10 -message "Stopping Windows Update service..."
        Stop-Service -Name wuauserv -Force -ErrorAction Stop
        Start-Sleep -Seconds 1
        Update-Progress -percent 40 -message "Deleting SoftwareDistribution folder..."
        Remove-Item -Path "C:\Windows\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Update-Progress -percent 70 -message "Starting Windows Update service..."
        Start-Service -Name wuauserv -ErrorAction Stop
        Update-Progress -percent 100 -message "Windows Update components repaired."
        [System.Windows.MessageBox]::Show("Windows Update components have been reset.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to repair Windows Update.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# 5. Check Disk for Errors (read-only scan)
$BtnCheckDisk.Add_Click({
    try {
        Update-Progress -percent 10 -message "Running CHKDSK scan..."
        $drive = (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq (Get-Location).Drive.Name }).Name + ":"
        $output = chkdsk $drive /scan 2>&1
        Update-Progress -percent 100 -message "CHKDSK scan completed."
        [System.Windows.MessageBox]::Show($output, "Check Disk Results", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to run CHKDSK.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# 6. Restart Windows Explorer
$BtnRestartExplorer.Add_Click({
    try {
        Update-Progress -percent 10 -message "Restarting Windows Explorer..."
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Update-Progress -percent 100 -message "Windows Explorer restarted."
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to restart Windows Explorer.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# 7. Clear Temporary Internet Files (Internet Explorer/Edge)
$BtnClearBrowserCache.Add_Click({
    try {
        Update-Progress -percent 10 -message "Clearing browser cache..."
        RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255
        Update-Progress -percent 100 -message "Browser cache cleared."
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to clear browser cache.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# 8. Reset Printer Queue
$BtnResetPrintQueue.Add_Click({
    try {
        Update-Progress -percent 10 -message "Stopping Print Spooler service..."
        Stop-Service -Name spooler -Force -ErrorAction Stop
        Start-Sleep -Seconds 1
        Update-Progress -percent 40 -message "Deleting printer queue files..."
        Remove-Item -Path "C:\Windows\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Update-Progress -percent 70 -message "Starting Print Spooler service..."
        Start-Service -Name spooler -ErrorAction Stop
        Update-Progress -percent 100 -message "Printer queue reset."
        [System.Windows.MessageBox]::Show("Printer queue has been reset.", "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to reset printer queue.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# 9. Run System File Checker (SFC)
$BtnRunSFC.Add_Click({
    try {
        Update-Progress -percent 10 -message "Running System File Checker (SFC)..."
        sfc /scannow
        Update-Progress -percent 100 -message "SFC scan completed."
        Update-Progress -percent 0 -message "Ready."
    }
    catch {
        [System.Windows.MessageBox]::Show("Failed to run System File Checker.`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Update-Progress -percent 0 -message "Ready."
    }
})

# Show the window
$window.ShowDialog()
