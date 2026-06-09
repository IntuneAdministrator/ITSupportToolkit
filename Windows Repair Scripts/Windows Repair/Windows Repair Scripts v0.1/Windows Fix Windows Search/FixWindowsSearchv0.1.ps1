<#
.SYNOPSIS
    A PowerShell script to reset and fix Windows Search by stopping the service, clearing the index, and restarting it.

.DESCRIPTION
    This PowerShell script automates the process of repairing the Windows Search service in case it becomes unresponsive or corrupted.
    The script provides a GUI interface for the user to initiate the fix. It performs the following actions:
    - Stops the Windows Search service.
    - Deletes search index files to resolve indexing issues.
    - Resets registry settings related to Windows Search.
    - Restarts the Windows Search service and waits until it is up and running.
    - A progress bar and status messages guide the user through each step.
    - Displays a message box upon completion with confirmation.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Admin rights to access system services and modify registry.
        - .NET Framework (for WPF and WinForms)
        - PowerShell 7+ or newer
    Known Issues :
        - Requires a restart of Windows Search for full functionality after reindexing.
        - Reindexing may take time depending on the amount of data.
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

# Define XAML layout
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Fix Windows Search Tool'
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
        <TextBlock Text='Fix Windows Search Tool' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='FixButton' Content='Fix Windows Search'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get WPF controls
$FixButton   = $window.FindName("FixButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText  = $window.FindName("StatusText")

# FixButton click event handler
$FixButton.Add_Click({
    $FixButton.IsEnabled = $false
    $StatusText.Text = "Resetting Windows Search..."

    for ($i = 0; $i -le 25; $i++) {
        $ProgressBar.Value = $i
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 25
    }

    # Stop and disable the Windows Search service
    sc.exe stop wsearch | Out-Null
    sc.exe config wsearch start= disabled | Out-Null
    $StatusText.Text = "Service stopped. Cleaning files..."

    for ($i = 26; $i -le 50; $i++) {
        $ProgressBar.Value = $i
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 25
    }

    # Reset registry and delete index files
    try {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Search" -Name "SetupCompletedSuccessfully" -Value 0 -Force
        Remove-Item -Path "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\*.db" -Force -ErrorAction SilentlyContinue
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error cleaning search data: $_","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
        $StatusText.Text = "Error during cleaning."
        $FixButton.IsEnabled = $true
        return
    }

    for ($i = 51; $i -le 75; $i++) {
        $ProgressBar.Value = $i
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 25
    }

    # Restart the Windows Search service
    sc.exe config wsearch start= delayed-auto | Out-Null
    sc.exe start wsearch | Out-Null

    do {
        Start-Sleep -Seconds 1
        $service = Get-Service wsearch -ErrorAction SilentlyContinue
    } while ($service.Status -ne 'Running')

    for ($i = 76; $i -le 100; $i++) {
        $ProgressBar.Value = $i
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 25
    }

    $StatusText.Text = "Search service restarted successfully."
    [System.Windows.Forms.MessageBox]::Show("Search has been reset and restarted.`nReindexing may take several days.", "Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

    $FixButton.IsEnabled = $true
})

# Show the window
$window.ShowDialog() | Out-Null
