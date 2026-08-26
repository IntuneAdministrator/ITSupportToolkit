@echo off
REM Intune Win32 uninstall wrapper
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-Toolkit.ps1"
exit /b %ERRORLEVEL%
