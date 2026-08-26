# Run On Active Directory macOS

Deploy **IT Repair & Diagnostic Toolkit** to Macs that use your **Active Directory / on-prem file share** (not Intune/Jamf cloud).

macOS has no Group Policy like Windows. Typical paths: **SMB share + root script** (ARD/SSH), or an optional **LaunchDaemon** at boot.

## What this folder contains

| File | Purpose |
|------|---------|
| `Computer-Startup.sh` | **Recommended** — install only if missing (run as root) |
| `Install-Toolkit.sh` | Always (re)copy toolkit + Applications launcher |
| `Uninstall-Toolkit.sh` | Remove install, launcher, and bootstrap LaunchDaemon |
| `Detect-Toolkit.sh` | Exit 0 if installed; exit 1 if not |
| `Install-Bootstrap-LaunchDaemon.sh` | Optional boot/hourly check from SMB share |

## Share layout

Host the **entire** toolkit on SMB/DFS (parent of `Install & Deployments`), including `IT Repair & Diagnostic Toolkit.app`, `Windows/`, `macOS/`, menus, etc.

```text
smb://fileserver/IT-Repair-Scripts/
  IT Repair & Diagnostic Toolkit.app
  Windows/
  macOS/
  Install & Deployments/
    Run On Active Directory macOS/
      Computer-Startup.sh
      ...
```

Build the `.app` once on a Mac (`Build-MacApp.sh`) before publishing the share.

## Deploy options

### A) Apple Remote Desktop / SSH (simple)

On each Mac (or a selected list):

```bash
sudo zsh "/Volumes/IT-Repair-Scripts/Install & Deployments/Run On Active Directory macOS/Computer-Startup.sh"
```

Mount the share first (Finder, or `mount_smbfs`).

### B) Optional LaunchDaemon (boot + hourly)

1. Edit `SHARE_UNC` inside `Install-Bootstrap-LaunchDaemon.sh`.
2. Run once as root (from a local copy or mounted share):

```bash
sudo zsh "Install & Deployments/Run On Active Directory macOS/Install-Bootstrap-LaunchDaemon.sh"
```

Adjust SMB auth for your AD (Kerberos / keychain / guest). Default wrapper exits quietly if the share is unreachable.

### C) Force reinstall / update

```bash
sudo zsh "Install & Deployments/Run On Active Directory macOS/Install-Toolkit.sh"
```

### Uninstall

```bash
sudo zsh "Install & Deployments/Run On Active Directory macOS/Uninstall-Toolkit.sh"
```

## Install layout (same as Intune / Jamf macOS)

| Path | Role |
|------|------|
| `/Library/Application Support/IT Repair & Diagnostic Toolkit/` | Full toolkit |
| `/Applications/IT Repair & Diagnostic Toolkit.app` | Thin launcher |

## After install (end user)

**Applications → IT Repair & Diagnostic Toolkit**.

## Notes

- This path is **on-prem / AD share macOS**. Cloud MDM: `Install & Deployments/Run On Cloud Intune macOS/` or `Run On Cloud Jamf macOS/`.
- Domain bind is optional for the toolkit itself; the share ACL and root execution matter more.
- Gatekeeper may block unsigned apps until your org allows them.
- Exit `0` = success; non-zero = failure (see root `README.md`).
