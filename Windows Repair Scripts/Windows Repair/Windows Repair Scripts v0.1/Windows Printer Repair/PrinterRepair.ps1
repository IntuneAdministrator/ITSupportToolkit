<#
.SYNOPSIS
    This script restarts the Print Spooler service and clears the print queue, providing a graphical user interface (GUI) built using XAML and WPF.

.DESCRIPTION
    This script allows the user to restart the Print Spooler service and clear the print queue. The script provides a simple GUI with a progress bar, which visually indicates the completion of each step in the process. This can be helpful for troubleshooting printer-related issues.
    The process involves stopping the print spooler service, clearing any stuck print jobs from the queue, and restarting the service. The user is also prompted with a message box once the task is completed.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Admin rights to stop/start services and access the print spooler directory.
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

# Load assemblies
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms

# Define XAML layout
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Restart Print Spooler'
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
        <TextBlock Text='Restart Print Spooler' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='RunButton' Content='Start Restart'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

$RunButton = $window.FindName("RunButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

function Update-UI {
    [System.Windows.Forms.Application]::DoEvents()
}

$printerSpoolPath = "$env:windir\System32\spool\PRINTERS"

$RunButton.Add_Click({
    $RunButton.IsEnabled = $false

    $steps = @(
        @{ Action = "Stopping print spooler service..."; Script = { Stop-Service -Name "Spooler" -Force -ErrorAction SilentlyContinue }; Progress = 25 },
        @{ Action = "Waiting for spooler to stop..."; Script = { Start-Sleep -Seconds 2 }; Progress = 40 },
        @{ Action = "Clearing print queue..."; Script = { Remove-Item "$printerSpoolPath\*.*" -Force -Recurse -ErrorAction SilentlyContinue }; Progress = 70 },
        @{ Action = "Waiting for queue clearance..."; Script = { Start-Sleep -Seconds 2 }; Progress = 80 },
        @{ Action = "Starting print spooler service..."; Script = { Start-Service -Name "Spooler" -ErrorAction SilentlyContinue }; Progress = 95 },
        @{ Action = "Finalizing..."; Script = { Start-Sleep -Seconds 2 }; Progress = 100 }
    )

    foreach ($step in $steps) {
        $StatusText.Text = "{0} {1}%" -f $step.Action, $step.Progress
        $ProgressBar.Value = $step.Progress
        Update-UI
        & $step.Script
    }

    $StatusText.Text = "Completed successfully!"
    Update-UI

    [System.Windows.MessageBox]::Show(
        'The print spooler has been restarted and the print queue cleared. Please try printing again.',
        'Operation Complete',
        'OK',
        'Information'
    )

    $RunButton.IsEnabled = $true
})

[void]$window.ShowDialog()
