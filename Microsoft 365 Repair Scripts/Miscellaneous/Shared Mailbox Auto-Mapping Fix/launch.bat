@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SharedMailboxAutoMappingFix.ps1"
if errorlevel 1 pause
exit
