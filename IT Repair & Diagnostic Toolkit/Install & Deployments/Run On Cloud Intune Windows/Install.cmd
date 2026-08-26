@echo off
REM Intune Win32 install wrapper
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Toolkit.ps1"
exit /b %ERRORLEVEL%
