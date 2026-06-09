<#
.SYNOPSIS
    BIOS Information Tool with modern WPF interface.

.DESCRIPTION
    This PowerShell script provides a graphical user interface (GUI) for retrieving and displaying detailed BIOS information from the local machine. The tool uses WPF (Windows Presentation Foundation) for a modern and user-friendly layout.
    
    When the user clicks the "Show BIOS Information" button, the script fetches system BIOS details such as serial number, manufacturer, BIOS version, release date, SMBIOS version, and more. The information is then displayed in a message box for the user to view.
    
    The script also provides progress feedback via a progress bar, updating the user as the BIOS information is retrieved. In case of an error during the process, an error message is displayed, and the progress bar shows a completion state.

.NOTES
    Author       : Allester Padovani  
    Date         : July 23, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2 with Microsoft 365 Outlook Desktop  
    Requirements : 
        - Admin rights for retrieving system BIOS information
        - Outlook installed (if additional Outlook features are needed)
        - .NET Framework (for WPF and WinForms) and PowerShell 7+
    
    This script uses the `Get-CimInstance` cmdlet to gather system BIOS details and requires administrative privileges to run successfully. It was designed to be compatible with modern versions of Windows and Outlook, offering a convenient way for IT administrators and users to access BIOS data from a simple GUI tool.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define modern consistent XAML layout
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='BIOS Information Tool'
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
        <TextBlock Text='BIOS Information Tool' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='ShowBiosButton' Content='Show BIOS Information'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Click the button to retrieve BIOS info.' FontSize='12' Foreground='black' Margin='0,0,0,10'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML and assign controls
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

$ShowBiosButton = $window.FindName("ShowBiosButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Click event for BIOS retrieval
$ShowBiosButton.Add_Click({
    try {
        $ProgressBar.Value = 10
        $StatusText.Text = "Gathering BIOS info..."

        $bios = Get-CimInstance -ClassName Win32_BIOS
        $ProgressBar.Value = 50

        $message = @"
BIOS Information:

Serial Number              : $($bios.SerialNumber)
Manufacturer               : $($bios.Manufacturer)
BIOS Version               : $($bios.SMBIOSBIOSVersion)
BIOS Release Date          : $($bios.ReleaseDate)
List Of Languages          : $($bios.ListOfLanguages -join ', ')
Primary BIOS               : $($bios.PrimaryBIOS)
SMBIOS Major Version       : $($bios.SMBIOSMajorVersion)
SMBIOS Minor Version       : $($bios.SMBIOSMinorVersion)
Software Element ID        : $($bios.SoftwareElementID)
Software Element State     : $($bios.SoftwareElementState)
Target Operating System    : $($bios.TargetOperatingSystem)
"@

        $ProgressBar.Value = 90

        [System.Windows.Forms.MessageBox]::Show(
            $message,
            "Detailed BIOS Information",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )

        $StatusText.Text = "BIOS information retrieved successfully."
        $ProgressBar.Value = 100
    } catch {
        $StatusText.Text = "Error retrieving BIOS information."
        $ProgressBar.Value = 100
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred: `n$($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# Show window
$window.ShowDialog()
