<#
.SYNOPSIS
    Sets "Speed & Duplex" to "1 Gbps Full Duplex" for all physical network adapters with a progress bar UI.

.DESCRIPTION
    The script enumerates all physical network adapters, attempts to set the "Speed & Duplex" advanced property to "1 Gbps Full Duplex" if available,
    and shows a responsive WPF GUI with a progress bar indicating operation progress.
    Results for each adapter are collected and displayed in a message box upon completion.

.AUTHOR
    Name        : Allester Padovani
    Title       : Senior IT Specialist
    Date        : 2025-07-19
    Version     : 1.0

.NOTES
    Requires administrative privileges.
    Tested on Windows 10/11.
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
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Define XAML layout (style matched)
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Speed &amp; Duplex Configuration'
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
        <TextBlock Text='Speed &amp; Duplex Configuration Tool' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button x:Name='StartButton' Content='Start Configuration'/>
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Find controls
$progressBar = $window.FindName("ProgressBar")
$statusText = $window.FindName("StatusText")
$startButton = $window.FindName("StartButton")

function Update-UI {
    param([string]$text, [int]$progress)
    $window.Dispatcher.Invoke([action]{
        $statusText.Text = $text
        $progressBar.Value = $progress
    })
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-MessageBox {
    param (
        [string]$Text,
        [string]$Title = "Speed & Duplex Configuration Results"
    )
    [System.Windows.Forms.MessageBox]::Show($Text, $Title, 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Information)
}

function Configure-SpeedDuplex {
    $startButton.IsEnabled = $false
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.HardwareInterface -eq $true }
        $count = $adapters.Count

        if ($count -eq 0) {
            Update-UI -text "No physical network adapters found." -progress 0
            Show-MessageBox -Text "No physical network adapters found on this system."
            return
        }

        $results = @()
        $index = 0

        foreach ($adapter in $adapters) {
            $index++
            $percent = [math]::Round(($index / $count) * 100)
            Update-UI -text "Processing adapter '$($adapter.Name)'... $percent%" -progress $percent

            try {
                $advancedProps = Get-NetAdapterAdvancedProperty -Name $adapter.Name
                $speedDuplexProp = $advancedProps | Where-Object {
                    $_.DisplayName -match 'Speed.*Duplex'
                }

                if ($null -ne $speedDuplexProp) {
                    $desiredValue = "1 Gbps Full Duplex"
                    if ($speedDuplexProp.DisplayValue -contains $desiredValue) {
                        Set-NetAdapterAdvancedProperty -Name $adapter.Name `
                            -DisplayName $speedDuplexProp.DisplayName `
                            -DisplayValue $desiredValue -NoRestart -ErrorAction Stop

                        $results += "Adapter '$($adapter.Name)': Speed & Duplex set to '$desiredValue'."
                    }
                    else {
                        $availableValues = $speedDuplexProp.DisplayValue -join ", "
                        $results += "Adapter '$($adapter.Name)': Desired value '$desiredValue' NOT available. Available values: $availableValues"
                    }
                }
                else {
                    $results += "Adapter '$($adapter.Name)': 'Speed & Duplex' property not found."
                }
            }
            catch {
                $results += "Adapter '$($adapter.Name)': Failed to set Speed & Duplex. Error: $_"
            }
        }

        if ($results.Count -eq 0) {
            $results = @("No adapters were processed.")
        }

        Update-UI -text "Configuration complete." -progress 100
        Show-MessageBox -Text ($results -join "`n")
    }
    catch {
        Update-UI -text "An unexpected error occurred." -progress 0
        Show-MessageBox -Text "An unexpected error occurred: $_" -Title "Error"
    }
    finally {
        $startButton.IsEnabled = $true
    }
}

# Wire up button click event
$startButton.Add_Click({
    Configure-SpeedDuplex
})

# Show the WPF window
$window.ShowDialog() | Out-Null
