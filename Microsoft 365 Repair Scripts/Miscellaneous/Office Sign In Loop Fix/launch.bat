@echo off
:: Get full path of the script
set "ScriptPath=%~dp0OfficeSignInLoopFix.ps1"

:: Run PowerShell hidden
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "& {Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%ScriptPath%""' -WindowStyle Hidden}"

exit
