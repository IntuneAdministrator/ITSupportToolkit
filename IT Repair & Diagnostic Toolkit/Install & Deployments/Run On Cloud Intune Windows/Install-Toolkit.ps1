#Requires -Version 5.1
<#
.SYNOPSIS
  Installs IT Repair & Diagnostic Toolkit for Intune Win32 (per-machine).
.NOTES
  Package the parent toolkit folder with the Microsoft Win32 Content Prep Tool.
  Install command:  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Install & Deployments\Run On Cloud Intune Windows\Install-Toolkit.ps1"
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ToolkitRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Dest = Join-Path $env:ProgramFiles 'IT Repair & Diagnostic Toolkit'

$copyNames = @(
    'IT Repair & Diagnostic Toolkit.exe'
    'MASTER-MENU.ps1'
    'MASTER-MENU-GUI.py'
    'Windows'
    'macOS'
    'README.md'
    'LICENSE'
    'RISK-INVENTORY.md'
    'IT Repair & Diagnostic Toolkit-macOS.command'
    'Build-MacApp.sh'
    'Install & Deployments\Run Locally Windows'
    'Install & Deployments\Run Locally macOS'
)

if (-not (Test-Path -LiteralPath (Join-Path $ToolkitRoot 'IT Repair & Diagnostic Toolkit.exe'))) {
    throw "IT Repair & Diagnostic Toolkit.exe not found next to package root: $ToolkitRoot"
}

New-Item -ItemType Directory -Path $Dest -Force | Out-Null

foreach ($name in $copyNames) {
    $src = Join-Path $ToolkitRoot $name
    if (-not (Test-Path -LiteralPath $src)) { continue }
    $target = Join-Path $Dest $name
    $parent = Split-Path -Parent $target
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path -LiteralPath $src -PathType Container) {
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        Copy-Item -LiteralPath $src -Destination $target -Recurse -Force
    } else {
        Copy-Item -LiteralPath $src -Destination $target -Force
    }
}

# Start Menu shortcut (all users)
$programs = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
New-Item -ItemType Directory -Path $programs -Force | Out-Null
$lnkPath = Join-Path $programs 'IT Repair & Diagnostic Toolkit.lnk'
$exe = Join-Path $Dest 'IT Repair & Diagnostic Toolkit.exe'
$w = New-Object -ComObject WScript.Shell
$sc = $w.CreateShortcut($lnkPath)
$sc.TargetPath = $exe
$sc.WorkingDirectory = $Dest
$sc.Description = 'IT Repair & Diagnostic Toolkit'
$ico = Join-Path $Dest 'Install & Deployments\Run Locally Windows\IT Repair & Diagnostic Toolkit.ico'
if (Test-Path -LiteralPath $ico) {
    $sc.IconLocation = "$ico,0"
} else {
    $sc.IconLocation = "$exe,0"
}
$sc.Save()

Write-Host "Installed to $Dest"
exit 0
