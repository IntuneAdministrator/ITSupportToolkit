<#
.SYNOPSIS
    Removes default Microsoft Store apps on Windows 11 via a GUI tool.

.DESCRIPTION
    This script provides a user interface for removing a list of default Microsoft Store apps on a Windows 11 machine.
    The script uses Group Policy to apply the removal policy and updates the registry with the appropriate keys to
    remove the specified apps. It provides progress feedback through a WPF GUI.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 25H2
    Requirements :
        - Admin rights to modify Group Policy and registry settings.
        - .NET Framework for WPF and WinForms.
        - PowerShell 7+ or newer.
        - Windows 11 or newer OS for compatibility with Microsoft Store apps.
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

# XAML layout with just one button
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Remove Microsoft Store Apps"
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
        <TextBlock Text="Remove Default Microsoft Store Apps (Windows 11 25H2)" 
                   FontSize="16" FontWeight="Bold" Margin="0,10,0,20"
                   HorizontalAlignment="Center"/>
        <Button x:Name="RemoveAppsBtn" Content="Apply App Removal Policy"/>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="400" Minimum="0" Maximum="100" Margin="0,10,0,10" Value="0"/>
        <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="black"/>
        <TextBlock Text=" Allester Padovani, Senior IT Specialist. All rights reserved." FontSize="12" FontStyle="Italic" Foreground="black" Margin="0,20,0,0" HorizontalAlignment="Center"/>
    </StackPanel>
</Window>
"@

# Load the XAML UI
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

function Animate-ProgressBar {
    param([int]$delay = 10)
    for ($i = 0; $i -le 100; $i += 5) {
        $ProgressBar.Value = $i
        $StatusText.Text = "Working... $i%"
        Start-Sleep -Milliseconds $delay
    }
    $ProgressBar.Value = 0
    $StatusText.Text = "Ready."
}

function Show-Result {
    param([string]$title, [string]$message)
    [System.Windows.MessageBox]::Show($message, $title, 'OK', 'Information') | Out-Null
}

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

# Show the window
$window.ShowDialog() | Out-Null
