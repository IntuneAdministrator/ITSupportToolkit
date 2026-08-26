@echo off
REM Active Directory / GPO install wrapper (Computer Startup or scheduled task)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Toolkit.ps1"
exit /b %ERRORLEVEL%
