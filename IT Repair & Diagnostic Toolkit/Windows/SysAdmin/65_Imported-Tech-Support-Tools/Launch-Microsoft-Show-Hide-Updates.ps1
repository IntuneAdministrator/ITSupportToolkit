#Requires -Version 5.1
<#
.SYNOPSIS
    Launch imported tech support tool: Microsoft Show Hide Updates
.DESCRIPTION
    Imported from ITSupportToolkit-main. Starts the primary executable / DiagCab / bat in _Tools.
.NOTES
    Author: Allester Padovani
    IT Repair & Diagnostic Toolkit | Imported Tech Support Tools
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$toolRoot = Join-Path $PSScriptRoot '_Tools\Microsoft Show Hide Updates'
if (-not (Test-Path -LiteralPath $toolRoot)) {
    Write-Error "Tool folder missing: $toolRoot"
    exit 2
}
$candidates = @()
$candidates += Get-ChildItem -LiteralPath $toolRoot -Recurse -File -Include *.exe,*.diagcab,*.DiagCab,*.bat,*.cmd -ErrorAction SilentlyContinue
$target = $candidates | Where-Object { $_.Extension -match '\.exe$' } | Select-Object -First 1
if (-not $target) { $target = $candidates | Select-Object -First 1 }
if (-not $target) {
    Write-Error "No runnable file found under $toolRoot"
    exit 2
}
Write-Host "Launching: $($target.FullName)" -ForegroundColor Cyan
Start-Process -FilePath $target.FullName -WorkingDirectory $target.DirectoryName
exit 0