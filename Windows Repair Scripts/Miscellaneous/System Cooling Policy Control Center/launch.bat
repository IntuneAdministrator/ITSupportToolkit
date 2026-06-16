@echo off

:: Get full path of the PowerShell script
set "ScriptPath=%~dp0SystemCooling.ps1"

:: Launch elevated PowerShell
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ^
"Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%ScriptPath%""' -Verb RunAs -WindowStyle Hidden"

exit