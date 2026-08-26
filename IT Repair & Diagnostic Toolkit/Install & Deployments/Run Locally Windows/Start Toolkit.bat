@echo off
REM Prefer the shortcut "IT Repair & Diagnostic Toolkit.lnk" for the custom icon.
REM This BAT is a plain fallback (Windows does not allow .ico on .bat files).
cd /d "%~dp0..\.."
if not exist "IT Repair & Diagnostic Toolkit.exe" (
  echo "IT Repair & Diagnostic Toolkit.exe" not found in:
  echo   %CD%
  pause
  exit /b 1
)
start "" "IT Repair & Diagnostic Toolkit.exe"
