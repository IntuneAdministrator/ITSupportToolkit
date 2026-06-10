Distribution – PowerShell Script
The entire distribution is handled by the “install.ps1” file.

In a first step I define the package name and the version. I also start a transcript of the process to have a log locally on the device.

$PackageName = "DesktopIcon_SLZ"
$Version = "1"

$Path_local = "$Env:Programfiles\MEM"
Start-Transcript -Path "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\$PackageName-install.log" -Force
Code language: PowerShell (powershell)
In the second step, I define and create the paths or folders that I need for the links and icons.

# Paths
$DesktopTMP = "$Path_local\Data\Desktop\$PackageName"
$DesktopIcons = "$Path_local\Data\icons\$PackageName"

# Create Folders
New-Item -Path $DesktopTMP -ItemType directory -force
New-Item -Path $DesktopIcons -ItemType directory -force
New-Item -Path "C:\Users\Public\Desktop" -ItemType directory -force
Code language: PowerShell (powershell)
Third, I remove possible previous versions of the package, its shortcuts on the desktop, and icons in the local folder.

# Remove old shortcuts and icons
$OLD_Items = Get-ChildItem -Path $DesktopTMP
foreach($OLD_Item in $OLD_Items){
    Remove-Item "C:\Users\Public\Desktop\$($OLD_Item.Name)" -Force
}
Remove-Item "$DesktopTMP\*" -Force
Remove-Item "$DesktopIcons\*" -Force
Code language: PowerShell (powershell)
In the fourth step I copy all predefined icons from the “Desktop” folder to the temporary local folder on the PC.

# Copy New shortcuts
Copy-Item -Path ".\Desktop\*" -Destination $DesktopTMP -Recurse
Copy-Item -Path ".\icons\*" -Destination $DesktopIcons -Recurse
Code language: PowerShell (powershell)
Then I read in the CSV and also create the defined shortcuts in the temporary desktop folder.

# shortcuts from list
$shortcuts = Import-CSV "link-list.csv"
foreach($shortcut in $shortcuts){
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut_file = $WshShell.CreateShortcut("$DesktopTMP\$($shortcut.name).lnk")
    $Shortcut_file.TargetPath = $shortcut.link
    $Shortcut_file.IconLocation = "$DesktopIcons\$($shortcut.icon)"
    $Shortcut_file.Save()
}
Code language: PowerShell (powershell)
After the copying process and the creation of all shortcuts, I copy them to the public desktop of the device.

# Copy icons to public Desktop
Copy-Item -Path "$DesktopTMP\*" -Destination "C:\Users\Public\Desktop" -Recurse
Code language: PowerShell (powershell)
Finally, I create a file that acts as a detection rule and contains the version of my package. I also stop the transcript.

# Validation
New-Item -Path "$Path_local\Validation\$PackageName" -ItemType "file" -Force -Value $Version

Stop-Transcript
Code language: PowerShell (powershell)
The detection rule
The detection rule reads the validation file and its content and compares it with the version number. If everything is correct, this is reported to Intune. If you adjust the package name or the version in “install.ps1”, you must also do this in “check.ps1”.

$PackageName = "DesktopIcon_SLZ"
$Version = "1"
$Path_local = "$Env:Programfiles\MEM"
$ProgramVersion_current = Get-Content -Path "$Path_local\Validation\$PackageName"

if($ProgramVersion_current -eq $Version){
    Write-Host "Found it!"
}