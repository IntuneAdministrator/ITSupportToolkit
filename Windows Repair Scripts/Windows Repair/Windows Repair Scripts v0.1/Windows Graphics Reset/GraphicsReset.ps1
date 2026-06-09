<#
.SYNOPSIS
    Resets the graphics driver by simulating the Ctrl+Shift+Win+B keypress sequence.

.DESCRIPTION
    This PowerShell script provides a graphical interface (WPF) that allows users to reset their graphics driver by simulating the keypress sequence Ctrl+Shift+Win+B.
    It features a simple button, a progress bar, and status text that provides feedback during the process.
    The tool checks for administrator privileges before executing and provides confirmation once the driver reset is successful.
    It is useful for troubleshooting graphics-related issues such as screen freezes or display problems on Windows.

.NOTES
    Author       : Allester Padovani
    Date         : July 24, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements : 
        - Administrator privileges to reset the graphics driver.
        - Windows 11 or later.
        - .NET Framework for WPF UI support.
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
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing

# Inline C# code to simulate key presses
$source = @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class KeyboardHelper
{
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int dwExtraInfo);

    private const int KEYEVENTF_EXTENDEDKEY = 0x1;
    private const int KEYEVENTF_KEYUP = 0x2;

    public static void PressKeyCombo()
    {
        keybd_event((byte)Keys.ControlKey, 0, KEYEVENTF_EXTENDEDKEY, 0);
        keybd_event((byte)Keys.ShiftKey, 0, KEYEVENTF_EXTENDEDKEY, 0);
        keybd_event((byte)Keys.LWin, 0, KEYEVENTF_EXTENDEDKEY, 0);
        keybd_event((byte)Keys.B, 0, KEYEVENTF_EXTENDEDKEY, 0);

        System.Threading.Thread.Sleep(200);

        keybd_event((byte)Keys.B, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
        keybd_event((byte)Keys.LWin, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
        keybd_event((byte)Keys.ShiftKey, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
        keybd_event((byte)Keys.ControlKey, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Windows.Forms"

# Check for Administrator privileges
function Check-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    if (-not $isAdmin) {
        [System.Windows.MessageBox]::Show(
            "This tool requires Administrator privileges.`nPlease run PowerShell as Administrator.",
            "Administrator Required",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
        exit
    }
}
Check-Admin

# XAML for the GUI window
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Graphics Driver Reset Tool' SizeToContent='WidthAndHeight'
        ResizeMode='NoResize' WindowStartupLocation='CenterScreen'
        Background='#f0f0f0' FontFamily='Segoe UI' FontSize='13'>
    <StackPanel Margin='20'>
        <TextBlock Text='Graphics Driver Reset (Ctrl + Shift + Win + B)' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button Name='btnReset' Content='Reset Graphics Driver' Height='20' FontSize='12' Foreground='black' FontWeight='Bold' Cursor='Hand' />
        <ProgressBar Name='progressBar' Height='20' Minimum='0' Maximum='100' Margin='0 15 0 10' />
        <TextBlock Name='txtStatus' Text='Ready.' TextAlignment='Left' Margin='0 0 0 15' />
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Find controls
$btnReset = $window.FindName("btnReset")
$progressBar = $window.FindName("progressBar")
$txtStatus = $window.FindName("txtStatus")

# UI refresh helper function
function Refresh-UI {
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

# Reset function with message box confirmation
function Reset-GraphicsDriver {
    try {
        $btnReset.IsEnabled = $false
        $progressBar.Value = 0
        $txtStatus.Text = "Sending key press sequence..."
        Refresh-UI

        [KeyboardHelper]::PressKeyCombo()

        Start-Sleep -Milliseconds 200
        $progressBar.Value = 100
        $txtStatus.Text = "Graphics driver reset command sent successfully."

        # Message box confirmation
        [System.Windows.MessageBox]::Show(
            "The screen has been refreshed successfully.",
            "Graphics Driver Reset",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
    }
    catch {
        $txtStatus.Text = "Failed to send keypress."
        [System.Windows.MessageBox]::Show(
            "An error occurred:`n$($_)",
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        )
    }
    finally {
        $progressBar.Value = 0
        $btnReset.IsEnabled = $true
        Refresh-UI
    }
}

# Hook up the button click event
$btnReset.Add_Click({
    Reset-GraphicsDriver
})

# Show the window
[void]$window.ShowDialog()
