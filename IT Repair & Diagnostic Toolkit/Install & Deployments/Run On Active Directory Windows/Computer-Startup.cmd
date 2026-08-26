@echo off
REM Idempotent Computer Startup helper for GPO.
REM Copies toolkit only when IT Repair & Diagnostic Toolkit.exe is missing under Program Files.
REM Point GPO → Computer Configuration → Policies → Windows Settings → Scripts → Startup
REM   at this file on a UNC share that contains the FULL toolkit parent folder.
REM Example:
REM   \\contoso.com\NETLOGON\IT-Repair-Scripts\Install & Deployments\Run On Active Directory Windows\Computer-Startup.cmd

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "& { $d='%~dp0Detect-Toolkit.ps1'; $i='%~dp0Install-Toolkit.ps1'; & $d; if ($LASTEXITCODE -ne 0) { & $i; exit $LASTEXITCODE } else { exit 0 } }"
exit /b %ERRORLEVEL%
