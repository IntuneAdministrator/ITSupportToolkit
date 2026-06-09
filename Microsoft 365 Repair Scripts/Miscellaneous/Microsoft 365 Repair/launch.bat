@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0Menu.ps1""' -WindowStyle Hidden"
exit
