@echo off
set "ScriptPath=%~dp0Invoke-M365UserOffboarding.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%ScriptPath%""'"

exit
