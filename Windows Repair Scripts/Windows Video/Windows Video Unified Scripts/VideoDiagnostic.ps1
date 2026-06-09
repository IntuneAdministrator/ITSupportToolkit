<#
.SYNOPSIS
    A GUI tool to manage webcam devices, including checking, uninstalling, updating drivers, and resetting privacy settings. 
    It also allows configuring dual monitor setups and restarting webcam devices.

.DESCRIPTION
    This PowerShell script provides a graphical interface using XAML for managing webcam devices on Windows. The script 
    includes the following functionalities:
    - Check for installed webcam devices and display their status.
    - Uninstall webcam devices and trigger automatic reinstallation of drivers by Windows.
    - Reset webcam privacy settings, allowing the user to restore access permissions.
    - Restart webcam devices by disabling and enabling them again.
    - Update webcam drivers using the built-in Windows `pnputil` tool.
    - Configure dual monitor setups by extending the display to multiple monitors.

    The interface includes progress bars and status messages, allowing for smooth transitions and feedback to the user during operations.

.NOTES
    Author       : Allester Padovani
    Date         : July 18, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements : Admin rights, Outlook installed, .NET Framework (for WPF and WinForms), PowerShell 7+
    
    This script uses the `pnputil` tool for updating drivers, and requires appropriate permissions to install drivers on the system.
    It will work on any system with a compatible version of Windows and requires the user to have administrative privileges.
    If executed without administrator rights, certain operations (such as driver updates or device uninstallation) may fail.
#>

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load necessary assemblies
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing

# Define the XAML
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Video Diagnostic &amp; Settings"
        Height="430" Width="460"
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
            <Setter Property="Margin" Value="0,0,0,10"/>
        </Style>
    </Window.Resources>
    <StackPanel Margin="20" HorizontalAlignment="Center">
        <TextBlock Text="Video Diagnostic &amp; Settings" FontSize="16" FontWeight="Bold" Margin="0,0,0,20"
                   HorizontalAlignment="Center"/>
        <Button x:Name="WebcamCheckButton" Content="Check Webcam Devices"/>
        <Button x:Name="WebcamUninstallButton" Content="Uninstall Webcam Devices"/>
        <Button x:Name="ResetPrivacyButton" Content="Reset Webcam Privacy Settings"/>
        <Button x:Name="RestartWebcamButton" Content="Restart Webcam Devices"/>
        <Button x:Name="UpdateDriversButton" Content="Update Webcam Drivers"/>
        <Button x:Name="DualMonitorButton" Content="Configure Dual Monitor Setup"/>
        <ProgressBar x:Name="ProgressBar" Height="20" Width="400" Minimum="0" Maximum="100" Margin="0,5,0,5" Value="0"/>
        <TextBlock x:Name="StatusText" Text="Ready." FontSize="12" Foreground="black"/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$xmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($xmlReader)

# Get button controls
$checkButton = $window.FindName("WebcamCheckButton")
$uninstallButton = $window.FindName("WebcamUninstallButton")
$resetPrivacyButton = $window.FindName("ResetPrivacyButton")
$restartWebcamButton = $window.FindName("RestartWebcamButton")
$updateButton = $window.FindName("UpdateDriversButton")
$dualMonitorButton = $window.FindName("DualMonitorButton")
$progressBar = $window.FindName("ProgressBar")
$statusText = $window.FindName("StatusText")

# Smoothly update progress bar from current value to target value
function Update-ProgressSmooth {
    param (
        [string]$message,
        [int]$targetProgress
    )

    # Clamp target between 0 and 100
    $targetProgress = [math]::Min([math]::Max($targetProgress, 0), 100)

    $window.Dispatcher.Invoke([action]{
        $current = [int]$progressBar.Value
        if ($targetProgress -le $current) {
            # If target is less or equal, just set immediately
            $progressBar.Value = $targetProgress
            $statusText.Text = $message
        } else {
            # Increment in steps for smooth animation
            for ($i = $current + 1; $i -le $targetProgress; $i++) {
                $progressBar.Value = $i
                Start-Sleep -Milliseconds 10
            }
            $statusText.Text = $message
        }
    })
}

# Function to check if running as admin
function Test-IsAdmin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

### Webcam Check Button ###
$checkButton.Add_Click({
    Update-ProgressSmooth -message "Checking webcam devices..." -targetProgress 10
    try {
        $webcams = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_PnPEntity |
            Where-Object { 
                ($_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image') -and
                ($_.Name -notmatch 'Printer|OfficeJet|Fax|Scan|Copy')
            }
        Start-Sleep -Milliseconds 300
        Update-ProgressSmooth -message "Processing devices..." -targetProgress 60

        if ($webcams.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "No webcam devices were found on this system.",
                "Webcam Status",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            Update-ProgressSmooth -message "No devices found." -targetProgress 0
            return
        } else {
            $statusReport = ""
            foreach ($cam in $webcams) {
                $statusReport += "Device Name: $($cam.Name)`n"
                $statusReport += "Status: $($cam.Status)`n"
                $statusReport += "Device ID: $($cam.DeviceID)`n"
                $statusReport += "----------------------------------------`n"
            }
            Start-Sleep -Milliseconds 200
            Update-ProgressSmooth -message "Showing results..." -targetProgress 90
            [System.Windows.Forms.MessageBox]::Show(
                $statusReport,
                "Webcam Devices Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            Update-ProgressSmooth -message "Ready." -targetProgress 0
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred: $_",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        Update-ProgressSmooth -message "Error encountered." -targetProgress 0
    }
})

### Webcam Uninstall Button ###
$uninstallButton.Add_Click({
    Update-ProgressSmooth -message "Preparing to uninstall webcam devices..." -targetProgress 5

    $userChoice = [System.Windows.Forms.MessageBox]::Show(
        "This will uninstall all detected webcam devices. Windows will reinstall drivers automatically." + [Environment]::NewLine + "Do you want to continue?",
        "Confirm Webcam Uninstall",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($userChoice -ne [System.Windows.Forms.DialogResult]::Yes) {
        Update-ProgressSmooth -message "Operation cancelled by user." -targetProgress 0
        return
    }

    try {
        $webcams = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_PnPEntity | Where-Object {
            ($_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image') -and
            ($_.Name -notmatch 'Printer|OfficeJet|Fax|Scan|Copy')
        }

        if (-not $webcams) {
            [System.Windows.Forms.MessageBox]::Show(
                "No webcam devices were detected on this system.",
                "No Devices Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            Update-ProgressSmooth -message "No webcam devices found." -targetProgress 0
            return
        }

        $total = $webcams.Count
        $uninstallFailures = @()
        $currentIndex = 0

        foreach ($cam in $webcams) {
            $currentIndex++
            $percent = [math]::Floor(($currentIndex / $total) * 100)
            Update-ProgressSmooth -message "Uninstalling: $($cam.Name) ($percent%)" -targetProgress $percent
            try {
                Remove-PnpDevice -InstanceId $cam.DeviceID -Confirm:$false -ErrorAction Stop
                Start-Sleep -Seconds 3
            } catch {
                $uninstallFailures += $cam.Name
            }
        }

        if ($uninstallFailures.Count -gt 0) {
            $failedList = ($uninstallFailures -join "`n")
            [System.Windows.Forms.MessageBox]::Show(
                "Some devices could not be uninstalled:`n`n$failedList`n`nPlease uninstall them manually or contact support.",
                "Manual Intervention Required",
                [System.Windows.Forms.MessageBox]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            Update-ProgressSmooth -message "Some devices failed to uninstall." -targetProgress 0
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "Webcam device(s) uninstalled successfully. Windows will reinstall drivers automatically.",
                "Operation Completed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            Update-ProgressSmooth -message "Uninstall completed." -targetProgress 100
            Start-Sleep -Seconds 1
            Update-ProgressSmooth -message "Ready." -targetProgress 0
        }

    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "An unexpected error occurred: $($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        Update-ProgressSmooth -message "Error encountered." -targetProgress 0
    }
})

### Reset Privacy Settings Button ###
$resetPrivacyButton.Add_Click({
    Update-ProgressSmooth -message "Resetting privacy settings..." -targetProgress 10
    try {
        # Registry keys to reset
        $keysToReset = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam"
        )

        foreach ($key in $keysToReset) {
            if (Test-Path $key) {
                Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Start-Sleep -Milliseconds 500
        Update-ProgressSmooth -message "Privacy settings reset." -targetProgress 80

        [System.Windows.Forms.MessageBox]::Show(
            "Webcam privacy settings have been reset. You may need to restart your computer for changes to take effect.",
            "Privacy Reset",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        Update-ProgressSmooth -message "Ready." -targetProgress 0
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to reset privacy settings: $_",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        Update-ProgressSmooth -message "Error encountered." -targetProgress 0
    }
})

### Restart Webcam Devices Button ###
$restartWebcamButton.Add_Click({
    try {
        $webcams = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_PnPEntity | Where-Object {
            ($_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image') -and
            ($_.Name -notmatch 'Printer|OfficeJet|Fax|Scan|Copy')
        }

        if (-not $webcams) {
            [System.Windows.Forms.MessageBox]::Show("No webcam devices found to restart.", "No Devices Detected", 'OK', 'Warning')
            return
        }

        foreach ($cam in $webcams) {
            try {
                Disable-PnpDevice -InstanceId $cam.PNPDeviceID -Confirm:$false -ErrorAction Stop
                Start-Sleep -Seconds 2
                Enable-PnpDevice -InstanceId $cam.PNPDeviceID -Confirm:$false -ErrorAction Stop
                Start-Sleep -Seconds 2
            } catch {
                Write-Warning "Failed to restart device $($cam.Name): $_"
            }
        }

        Update-UI -message "Restart process completed." -progress 100
        Start-Sleep -Seconds 1
        [System.Windows.MessageBox]::Show("Webcam restart process completed successfully.",
            "Driver Update", 'OK', 'Information')

    } catch {
        Update-UI -message "An error occurred during update."
        [System.Windows.MessageBox]::Show("An error occurred: $($_.Exception.Message)", "Error", 'OK', 'Error')
    } finally {
        $updateButton.IsEnabled = $true
        Update-UI -message "Ready." -progress 0
    }
})

### Update Webcam Drivers Button ###
$updateButton.Add_Click({
    if (-not (Test-IsAdmin)) {
        [System.Windows.MessageBox]::Show("Please run this tool as Administrator.","Insufficient Privileges",
            'OK', 'Error')
        return
    }

    $updateButton.IsEnabled = $false
    Update-UI -message "Gathering webcam devices..." -progress 5

    try {
        $cameras = Get-PnpDevice -Class "Camera" -Status OK -ErrorAction SilentlyContinue
        $mediaDevices = Get-PnpDevice -Class "Media" -Status OK -ErrorAction SilentlyContinue

        $allDevices = @()
        if ($cameras) { $allDevices += $cameras }
        if ($mediaDevices) { $allDevices += $mediaDevices }

        $webcams = $allDevices | Where-Object {
            $_.FriendlyName -match 'camera|webcam'
        }

        if (-not $webcams) {
            Update-UI -message "No enabled webcam devices found to update." -progress 0
            [System.Windows.MessageBox]::Show("No enabled webcam devices found to update.","No Devices Found",
                'OK', 'Warning')
            $updateButton.IsEnabled = $true
            return
        }

        $totalDevices = $webcams.Count
        $currentIndex = 0

        foreach ($device in $webcams) {
            $currentIndex++
            $percent = [math]::Floor(($currentIndex / $totalDevices) * 100)
            Update-UI -message "Updating driver for: $($device.FriendlyName) ($percent%)" -progress $percent

            try {
                & "$env:SystemRoot\System32\pnputil.exe" /update-driver "$($device.InstanceId)" /install | Out-Null
            }
            catch {
                Write-Warning "Failed to update driver for: $($device.FriendlyName). Error: $_"
            }
        }

        Update-UI -message "Driver update process completed." -progress 100
        Start-Sleep -Seconds 1
        [System.Windows.MessageBox]::Show("Webcam driver update process completed successfully.",
            "Driver Update", 'OK', 'Information')

    } catch {
        Update-UI -message "An error occurred during update."
        [System.Windows.MessageBox]::Show("An error occurred: $($_.Exception.Message)", "Error", 'OK', 'Error')
    } finally {
        $updateButton.IsEnabled = $true
        Update-UI -message "Ready." -progress 0
    }
})

### Dual Monitor Setup Button ###
$dualMonitorButton.Add_Click({
    Update-ProgressSmooth -message "Checking monitor configuration..." -targetProgress 10
    try {
        # Prompt user to confirm extending the desktop
        $userChoice = [System.Windows.Forms.MessageBox]::Show(
            "Do you want to configure the dual monitor setup to Extend mode?",
            "Confirm Dual Monitor Setup",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($userChoice -eq [System.Windows.Forms.DialogResult]::Yes) {
            # Function to retrieve connected monitors
            function Get-ConnectedMonitors {
                Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams | 
                Select-Object InstanceName, MaxHorizontalImageSize, MaxVerticalImageSize
            }

            # Get connected monitors
            $monitors = Get-ConnectedMonitors

            # Check if at least two monitors are connected
            if ($monitors.Count -lt 2) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Less than two monitors detected. Please connect a second monitor to proceed.",
                    "Dual Monitor Setup",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                Update-ProgressSmooth -message "Not enough monitors detected." -targetProgress 0
                return
            }

            # Extend desktop across monitors using DisplaySwitch.exe
            Start-Process -FilePath "C:\Windows\System32\DisplaySwitch.exe" -ArgumentList "/extend" -Wait

            # Inform user of success
            [System.Windows.Forms.MessageBox]::Show(
                "Dual monitor setup has been configured to Extend mode. Please adjust resolution and primary monitor in Display Settings as needed.",
                "Dual Monitor Setup",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            Update-ProgressSmooth -message "Dual monitor setup completed." -targetProgress 100
            Start-Sleep -Seconds 1
            Update-ProgressSmooth -message "Ready." -targetProgress 0
        } else {
            Write-Host "Operation cancelled by user."
            Update-ProgressSmooth -message "Operation cancelled." -targetProgress 0
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "An error occurred during dual monitor setup:`n$_",
            "Dual Monitor Setup Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        Update-ProgressSmooth -message "Error encountered." -targetProgress 0
    }
})

# Show the window
$window.ShowDialog() | Out-Null
