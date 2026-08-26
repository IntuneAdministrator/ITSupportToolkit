@echo off
setlocal EnableExtensions
:: Start_WMT_GUI.bat version 1.1 (matches WMT-GUI.ps1 $AppVersion)
set "GUI_LAUNCHER_VERSION=1.1"
:: Launch WMT-GUI.ps1 silently (no extra console) with elevation.

for %%I in ("%~dp0WMT-GUI.ps1") do set "SCRIPT=%%~fI"

if not exist "%SCRIPT%" (
  echo [ERROR] WMT-GUI.ps1 was not found in: %~dp0
  pause
  exit /b 1
)

:: Guard against accidentally downloaded HTML page (GitHub blob) renamed as .ps1
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p='%SCRIPT%'; $head=((Get-Content -Path $p -TotalCount 120 -ErrorAction SilentlyContinue) -join \"`n\"); if($head -match '(?is)<!doctype\s+html|<html\b|<head\b|<body\b|<meta\b[^>]*charset'){ exit 42 } else { exit 0 }"

if "%ERRORLEVEL%"=="42" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Add-Type -AssemblyName PresentationFramework; $msg='Invalid WMT-GUI.ps1 detected.' + [Environment]::NewLine + 'It looks like an HTML page was downloaded instead of the raw PowerShell script.' + [Environment]::NewLine + [Environment]::NewLine + 'Please download from Releases or use the raw file link.'; [System.Windows.MessageBox]::Show($msg,'WMT Launcher Error',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null"
  start "" "https://github.com/ios12checker/Windows-Maintenance-Tool/releases"
  exit /b 1
)

:: Launch script directly. Elevation is handled inside WMT-GUI.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT%"
set "LAUNCH_EXIT=%ERRORLEVEL%"
if not "%LAUNCH_EXIT%"=="0" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Add-Type -AssemblyName PresentationFramework; $msg='Failed to start WMT-GUI.ps1.' + [Environment]::NewLine + 'Launcher exit code: %LAUNCH_EXIT%' + [Environment]::NewLine + [Environment]::NewLine + 'Path:' + [Environment]::NewLine + '%SCRIPT%'; [System.Windows.MessageBox]::Show($msg,'WMT Launcher Error',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null"
  exit /b %LAUNCH_EXIT%
)

endlocal
