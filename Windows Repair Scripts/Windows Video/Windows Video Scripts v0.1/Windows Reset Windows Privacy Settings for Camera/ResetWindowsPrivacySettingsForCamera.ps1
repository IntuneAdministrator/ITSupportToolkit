<#
.SYNOPSIS
    A tool to reset webcam privacy settings for apps on a Windows system. This script provides a graphical interface to reset the privacy settings for webcam access by applications.

.DESCRIPTION
    This script provides a graphical user interface (GUI) to reset webcam privacy settings for applications in Windows. It works by accessing the registry key that holds the permissions for webcam access for different applications. It will:
    - Query the registry for webcam privacy settings stored under the user profile.
    - Reset any disallowed access to 'Allow'.
    - Update the user interface with a progress bar and status updates during the process.
    - Provide a final message box with a verification of which apps have been granted access.

    The script also includes error handling in case the registry settings are not found or other issues arise during the execution.

.NOTES
    Author       : Allester Padovani  
    Date         : July 18, 2025  
    Version      : 1.0  
    Tested On    : Windows 11 24H2
    Requirements : Admin rights, .NET Framework (for WPF), and appropriate registry access to modify privacy settings for webcam permissions.

    Changes in Version 1.0:
    - Initial release of the tool.
    - Provides functionality to reset webcam privacy settings for apps.
    - Includes progress bar and verification of changes.
    - Displays notifications if no webcam privacy settings exist or if an error occurs during the process.

#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load necessary assemblies for WPF and Windows Forms
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define the XAML layout for the UI
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Webcam Privacy Settings'
        Height='430' Width='460'
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
        <TextBlock Text='Reset Webcam Privacy Settings' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='ResetPrivacyButton' Content='Reset Camera Privacy'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML into a Window object
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get UI elements
$ResetPrivacyButton = $window.FindName("ResetPrivacyButton")
$ProgressBar = $window.FindName("ProgressBar")
$StatusText = $window.FindName("StatusText")

# Define the logic for resetting the webcam privacy settings
$ResetPrivacyButton.Add_Click({
    try {
        # Define the registry key containing camera privacy permissions
        $privacyKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam"
        
        # Check if the webcam privacy key exists in the registry
        if (-not (Test-Path $privacyKey)) {
            # If the key doesn't exist, inform the user and stop execution
            [System.Windows.Forms.MessageBox]::Show(
                "Camera privacy settings not found. This may indicate no camera has been used on this account.",
                "No Settings Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            $StatusText.Text = "Camera privacy settings not found."
            $ProgressBar.Value = 100
            return
        }

        # Retrieve all subkeys under the webcam registry key
        $subKeys = Get-ChildItem -Path $privacyKey

        # Reset progress bar and set status message
        $ProgressBar.Value = 0
        $StatusText.Text = "Resetting camera privacy settings..."

        # Loop through each subkey and update the 'Value' to 'Allow'
        $totalSubKeys = $subKeys.Count
        $updatedCount = 0
        foreach ($key in $subKeys) {
            Set-ItemProperty -Path $key.PSPath -Name "Value" -Value "Allow" -ErrorAction Stop
            $updatedCount++
            $ProgressBar.Value = (($updatedCount) / $totalSubKeys) * 100
        }

        # If all settings are updated, notify the user
        [System.Windows.Forms.MessageBox]::Show(
            "Camera privacy settings have been successfully reset. App access is now allowed.",
            "Privacy Settings Updated",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )

        $StatusText.Text = "Camera privacy settings successfully reset."
        $ProgressBar.Value = 100

        # Verification: Check if the 'Value' is successfully set to 'Allow'
        $verificationMessage = "Privacy settings verification:" + [Environment]::NewLine
        foreach ($key in $subKeys) {
            $appName = $key.PSChildName
            $privacyStatus = Get-ItemProperty -Path $key.PSPath -Name "Value"

            if ($privacyStatus.Value -eq "Allow") {
                $verificationMessage += "$appName is allowed access to the webcam." + [Environment]::NewLine
            } else {
                $verificationMessage += "$appName is NOT allowed access to the webcam." + [Environment]::NewLine
            }
        }

        # Show verification result in a message box
        [System.Windows.Forms.MessageBox]::Show(
            $verificationMessage,
            "Verification Complete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )

    } catch {
        # Capture and display any errors encountered during execution
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred while modifying privacy settings:`n$($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        $StatusText.Text = "Error occurred: $_"
        $ProgressBar.Value = 100
    }
})

# Show the window
$window.ShowDialog()
