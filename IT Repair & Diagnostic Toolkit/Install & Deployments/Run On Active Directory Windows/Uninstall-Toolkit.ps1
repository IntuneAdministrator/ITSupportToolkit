#Requires -Version 5.1
<#
.SYNOPSIS
  Removes IT Repair & Diagnostic Toolkit (AD / GPO uninstall or cleanup).
.NOTES
  Computer Shutdown script or one-off admin run:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "\\share\...\Install & Deployments\Run On Active Directory Windows\Uninstall-Toolkit.ps1"
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'SilentlyContinue'

$Dest = Join-Path $env:ProgramFiles 'IT Repair & Diagnostic Toolkit'
$lnk = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\IT Repair & Diagnostic Toolkit.lnk'

if (Test-Path -LiteralPath $lnk) {
    Remove-Item -LiteralPath $lnk -Force
}
if (Test-Path -LiteralPath $Dest) {
    Remove-Item -LiteralPath $Dest -Recurse -Force
}

Write-Host 'IT Repair & Diagnostic Toolkit removed.'
exit 0
