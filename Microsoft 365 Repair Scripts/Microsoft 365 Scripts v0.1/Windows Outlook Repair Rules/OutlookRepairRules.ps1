<#
.SYNOPSIS
    Closes Outlook and resets all email rules to default using the /cleanrules switch.

.DESCRIPTION
    This script detects if Microsoft Outlook is currently running. If so, it forcefully terminates the Outlook process
    to avoid conflicts during the rule reset. After confirming Outlook is fully closed, the script launches Outlook 
    with the `/cleanrules` switch, which removes all client-side and server-side rules configured by the user.
    Once the operation is triggered, a message box notifies the user that the reset is complete.
    This script is helpful for resolving rule corruption, sync issues, or starting fresh with rule configuration.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2 with Microsoft 365 Outlook Desktop  
    Requirements : Admin rights, Outlook installed, .NET Framework (for WPF and WinForms)
#>

# Elevate if not admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    try {
        Start-Process powershell -Verb RunAs -ArgumentList $arguments
    } catch {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            "Administrator privileges are required to run this script.",
            "Permission Denied",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# WASAPI style XAML layout
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Reset Outlook Rules'
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
        <TextBlock Text='Reset Outlook Rules to Default' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='ResetButton' Content='Reset Outlook Rules'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Value='0' Margin='0,5,0,5'/>
        <TextBlock x:Name='StatusText' Text='' FontSize='12' Foreground='black' HorizontalAlignment='Center' Margin='0,10,0,10'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML window
[xml]$xmlDoc = New-Object System.Xml.XmlDocument
$xmlDoc.LoadXml($xaml)
$reader = New-Object System.Xml.XmlNodeReader $xmlDoc
$window = [Windows.Markup.XamlReader]::Load($reader)

# Access controls
$ResetButton = $window.FindName("ResetButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# UI responsiveness helper
function Do-Events { [System.Windows.Forms.Application]::DoEvents() }

# Smooth progress bar update
function Update-Progress {
    param ([string]$Message, [int]$TargetValue)
    $StatusText.Text = $Message
    for ($i = $ProgressBar.Value; $i -lt $TargetValue; $i++) {
        $ProgressBar.Value = $i
        Do-Events
        Start-Sleep -Milliseconds 20
    }
}

# Button click logic
$ResetButton.Add_Click({
    $ResetButton.IsEnabled = $false

    Update-Progress -Message "Checking for running Outlook..." -TargetValue 20
    $Outlook = Get-Process -Name "Outlook" -ErrorAction SilentlyContinue
    if ($Outlook) {
        $StatusText.Text = "Closing Outlook..."
        Stop-Process -Name "Outlook" -Force
        Start-Sleep -Seconds 3
    }

    Update-Progress -Message "Launching Outlook with /cleanrules..." -TargetValue 70
    Start-Process "OUTLOOK.EXE" -ArgumentList "/cleanrules"
    Start-Sleep -Seconds 2

    Update-Progress -Message "Reset complete." -TargetValue 100
    $StatusText.Text = "Outlook rules have been reset."

    [System.Windows.MessageBox]::Show(
        "Outlook rules have been reset to default.",
        "Reset Complete",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information)
    $window.Close()
})

# Show the GUI
$window.ShowDialog() | Out-Null
