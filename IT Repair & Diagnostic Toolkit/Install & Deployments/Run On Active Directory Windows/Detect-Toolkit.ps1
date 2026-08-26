#Requires -Version 5.1
<#
.SYNOPSIS
  Detection — exit 0 + output = installed; exit 1 = not installed.
  Used by Computer-Startup.cmd (skip reinstall) and by admins for health checks.
#>
[CmdletBinding()]
param()
$exe = Join-Path $env:ProgramFiles 'IT Repair & Diagnostic Toolkit\IT Repair & Diagnostic Toolkit.exe'
if (Test-Path -LiteralPath $exe) {
    Write-Output 'IT Repair & Diagnostic Toolkit detected'
    exit 0
}
exit 1
