<#
.SYNOPSIS
    Repairs the current user's profile and optionally creates a new admin account using a WPF GUI.

.DESCRIPTION
    This PowerShell script provides a graphical user interface (GUI) to repair a corrupted user profile by creating a new temporary administrator account. The script checks for administrator privileges before proceeding and allows users to interact with a clean, user-friendly interface to input credentials for the new admin account.
    The GUI also includes a progress bar that simulates the process of creating the user account.
    A confirmation message is displayed after successfully creating the temporary admin account, and users can choose to restart the computer to use the newly created account.

.NOTES
    Author       : Allester Padovani
    Date         : July 23, 2025
    Version      : 1.0
    Tested On    : Windows 11 24H2
    Requirements :
        - Administrator privileges are required to run this script.
        - Windows 10 or later.
        - PowerShell 5.1 or later.
        - .NET Framework for WPF GUI.
    Known Limitations:
        - The new user is temporary; it is recommended to delete the user after use.
        - The script does not repair profile corruption directly; it only creates an admin account for troubleshooting purposes.
#>

# Ensure script is running as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("This script must be run as Administrator.","Permission Denied",
        [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# Check if the script is running as Administrator
$runAsAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $runAsAdmin) {
    # Relaunch the script as administrator if not running with elevated privileges
    $argList = $MyInvocation.MyCommand.Definition
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$argList`"" -Verb RunAs
    exit
}

# Load GUI assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# XAML layout with REPAIR button removed
$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Repair Corrupted Profile'
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
        <TextBlock Text='Repair Corrupted Profile' FontSize='16' FontWeight='Bold' Margin='0,0,0,20' HorizontalAlignment='Center'/>
        <Button Name="BtnCreateUser" Content="Create Temporary Admin User" />
        <ProgressBar x:Name='ProgressBar' Height='20' Width='400' Minimum='0' Maximum='100' Margin='0,5,0,5' Value='0'/>
        <TextBlock x:Name='StatusText' Text='Ready.' FontSize='12' Foreground='black' Margin='0,5,0,0'/>
        <TextBlock Text='© Allester Padovani, Senior IT Specialist. All rights reserved.' FontSize='12' FontStyle='Italic' Foreground='black' Margin='0,20,0,0' HorizontalAlignment='Center'/>
    </StackPanel>
</Window>
"@

# Load XAML UI
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$btnCreateUser = $window.FindName("BtnCreateUser")
$progressBar = $window.FindName("ProgressBar")

# Simulated progress bar
function Update-ProgressBar {
    for ($i=0; $i -le 100; $i += 20) {
        Start-Sleep -Milliseconds 200
        $progressBar.Dispatcher.Invoke([action]{ $progressBar.Value = $i })
        [System.Windows.Forms.Application]::DoEvents()
    }
    $progressBar.Dispatcher.Invoke([action]{ $progressBar.Value = 0 })
}

# Credential input form
function Show-CredentialInputForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Create Temporary Admin Account"
    $form.Size = New-Object System.Drawing.Size(350, 200)
    $form.StartPosition = "CenterScreen"
    $form.Topmost = $true

    $lblUser = New-Object System.Windows.Forms.Label -Property @{Text="New Username:";Location=New-Object Drawing.Point(10,20);Size=New-Object Drawing.Size(100,20)}
    $txtUser = New-Object System.Windows.Forms.TextBox -Property @{Location=New-Object Drawing.Point(120,20);Size=New-Object Drawing.Size(200,20)}
    $lblPass = New-Object System.Windows.Forms.Label -Property @{Text="New Password:";Location=New-Object Drawing.Point(10,60);Size=New-Object Drawing.Size(100,20)}
    $txtPass = New-Object System.Windows.Forms.TextBox -Property @{Location=New-Object Drawing.Point(120,60);Size=New-Object Drawing.Size(200,20);UseSystemPasswordChar=$true}

    $okButton = New-Object System.Windows.Forms.Button -Property @{Text="Create";Location=New-Object Drawing.Point(120,110)}
    $okButton.Add_Click({
        if ($txtUser.Text -and $txtPass.Text) {
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Both fields are required.","Input Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })

    $cancelButton = New-Object System.Windows.Forms.Button -Property @{Text="Cancel";Location=New-Object Drawing.Point(220,110)}
    $cancelButton.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $form.Close() })

    $form.Controls.AddRange(@($lblUser,$txtUser,$lblPass,$txtPass,$okButton,$cancelButton))
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    if ($form.ShowDialog() -eq 'OK') {
        return @{Username=$txtUser.Text; Password=$txtPass.Text}
    } else {
        return $null
    }
}

# Button actions
$btnCreateUser.Add_Click({
    Update-ProgressBar

    $creds = Show-CredentialInputForm
    if ($null -eq $creds) {
        [System.Windows.Forms.MessageBox]::Show("Operation canceled.","Canceled",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    try {
        $securePass = ConvertTo-SecureString $creds.Password -AsPlainText -Force
        New-LocalUser -Name $creds.Username -Password $securePass -FullName "Temporary Admin User" -Description "Created by Profile Repair GUI"
        Add-LocalGroupMember -Group "Administrators" -Member $creds.Username

        [System.Windows.Forms.MessageBox]::Show("Temporary admin user '$($creds.Username)' created successfully.","Success",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)

        $restart = [System.Windows.Forms.MessageBox]::Show("Restart now to use this account?","Restart Required",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
        if ($restart -eq "Yes") {
            [System.Windows.Forms.MessageBox]::Show("Save your work. Restarting in 2 minutes...","Notice",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
            shutdown.exe /r /t 120
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error creating user: $_","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Show the GUI
$window.ShowDialog() | Out-Null
