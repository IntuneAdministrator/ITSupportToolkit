# Run On Active Directory Windows

Deploy **IT Repair & Diagnostic Toolkit** to domain-joined Windows PCs via **Group Policy** (or any AD-targeted software share).

## What this folder contains

| File | Purpose |
|------|---------|
| `Computer-Startup.cmd` | **Recommended** GPO Startup script — installs only if missing |
| `Install-Toolkit.ps1` / `Install.cmd` | Always (re)copy toolkit to `%ProgramFiles%\IT Repair & Diagnostic Toolkit` + Start Menu shortcut |
| `Uninstall-Toolkit.ps1` / `Uninstall.cmd` | Remove install + shortcut |
| `Detect-Toolkit.ps1` | Exit 0 if installed; exit 1 if not |

## Share layout

Host the **entire** toolkit folder on DFS, NETLOGON, or a secured file share (parent of `Install & Deployments`), including `Windows\`, `macOS\`, `IT Repair & Diagnostic Toolkit.exe`, menus, etc.

Example UNC:

```text
\\contoso.com\NETLOGON\IT-Repair-Scripts\
  IT Repair & Diagnostic Toolkit.exe
  Windows\
  macOS\
  Install & Deployments\
    Run On Active Directory Windows\
      Computer-Startup.cmd
      Install-Toolkit.ps1
      ...
```

Computers need **read** access to that share (Authenticated Users or a computer group). Startup runs as **SYSTEM**.

## Deploy with Group Policy

1. Copy the full toolkit to the share (above).
2. GPMC → create/edit a GPO linked to the OU of target PCs.
3. **Computer Configuration → Policies → Windows Settings → Scripts (Startup/Shutdown) → Startup**
   - **Add** → **Browse** to:  
     `\\...\IT-Repair-Scripts\Install & Deployments\Run On Active Directory Windows\Computer-Startup.cmd`
4. Scope the GPO (security filtering / WMI as needed).
5. On clients: `gpupdate /force` or wait for next reboot.

### Force reinstall / update

Use **Install.cmd** (or `Install-Toolkit.ps1`) as the Startup script once, or run it as SYSTEM from the share after you refresh the share copy. Then switch back to `Computer-Startup.cmd` if you want idempotent startups.

### Uninstall via GPO

**Computer Configuration → Scripts → Shutdown** (or a temporary Startup) → `Uninstall.cmd`.

## After install (end user)

Start Menu → **IT Repair & Diagnostic Toolkit** → opens `IT Repair & Diagnostic Toolkit.exe`.

## Notes

- This path is **domain Windows / GPO**. Cloud MDM: `Install & Deployments\Run On Cloud Intune Windows\`.
- Same on-disk layout as Intune: `%ProgramFiles%\IT Repair & Diagnostic Toolkit`.
- Exit `0` = success; non-zero = failure (see root `README.md`).
- Unsigned EXE may trigger SmartScreen — use org code signing / AppLocker in production.
- Prefer a **DFS** or replicated NETLOGON path so all sites see the same package.
