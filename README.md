# IT Repair & Diagnostic Toolkit

Production helpdesk / SysAdmin toolkit for **Windows** and **macOS**, with a unified catalog GUI, risk labels, logging, and HTML reports.

**Author:** Allester Padovani

---

## Overview

| Layer | Purpose |
|-------|---------|
| `IT Repair & Diagnostic Toolkit.exe` | Windows start screen → **Windows** opens `MASTER-MENU.ps1`; **macOS** opens `MASTER-MENU-GUI.py` |
| `MASTER-MENU.ps1 -Gui` | WPF catalog (Windows host; can browse macOS scripts) |
| `IT Repair & Diagnostic Toolkit.app` | **macOS GUI for technicians** (no Python install) — build with `Build-MacApp.sh` |
| `IT Repair & Diagnostic Toolkit-macOS.command` | Finder helper → prefers `.app`, else `python3 MASTER-MENU-GUI.py` |
| `MASTER-MENU-GUI.py` | Source GUI (dev / Windows macOS-browse / Mac before you build the `.app`) |
| `Windows/` · `macOS/` | Script libraries (`SysAdmin` + `ITSupport`) |

Catalog shape: **Platform → Role → Theme → Category (`NN_Name`) → Scripts**.

---

## Folder structure

```
IT-Repair-Scripts/
├── IT Repair & Diagnostic Toolkit.exe
├── IT Repair & Diagnostic Toolkit.app          # after Mac build (optional until built)
├── IT Repair & Diagnostic Toolkit-macOS.command
├── Build-MacApp.sh
├── MASTER-MENU.ps1
├── MASTER-MENU-GUI.py
├── README.md · LICENSE · RISK-INVENTORY.md
├── Install & Deployments/         # local launchers + Intune / Jamf / AD packages
│   ├── Run Locally Windows/
│   ├── Run Locally macOS/
│   ├── Run On Active Directory Windows/
│   ├── Run On Active Directory macOS/
│   ├── Run On Cloud Intune Windows/
│   ├── Run On Cloud Intune macOS/
│   └── Run On Cloud Jamf macOS/
├── Windows/
│   ├── SysAdmin/NN_Category/*.ps1
│   └── ITSupport/NN_Category/*.ps1
└── macOS/
    ├── SysAdmin/NN_Category/*.{sh,ps1}
    └── ITSupport/NN_Category/*.{sh,ps1}
```

Menus discover **only scripts in the category root** (non-recursive). Imported Tech Support binaries live once under `Windows/SysAdmin/65_Imported-Tech-Support-Tools/_Tools/`; IT Support `Launch-*.ps1` wrappers point there.

---

## Requirements

| Host | Requirement |
|------|-------------|
| Windows | Windows 10/11, PowerShell **5.1+** (7.x supported), .NET for WPF GUI |
| macOS (technicians) | **`IT Repair & Diagnostic Toolkit.app`** only — no Python install |
| macOS (build once) | Mac with Python **3.9+** + `tkinter` to run `Build-MacApp.sh` |
| Python GUI (source) | Python 3.9+ stdlib (`tkinter`) — Windows browse / Mac before `.app` exists |
| Imported M365 | Optional modules: ExchangeOnlineManagement, Microsoft.Graph.*, PnP.PowerShell |

---

## How to run

**Windows**

1. Keep `IT Repair & Diagnostic Toolkit.exe` next to `MASTER-MENU.ps1`.
2. Double-click the exe → choose Platform + Role → **Open Toolkit**.
3. Or: `powershell -NoProfile -ExecutionPolicy Bypass -File .\MASTER-MENU.ps1 -Gui`

**macOS (technicians — no Python)**

1. Double-click `IT Repair & Diagnostic Toolkit.app` (must sit next to `Windows/` and `macOS/`).
2. Or double-click `IT Repair & Diagnostic Toolkit-macOS.command` (prefers the `.app` if present).

Theme preference is stored locally in `toolkit-theme.cfg` (created automatically; do not redistribute that file).

---

## Building `IT Repair & Diagnostic Toolkit.app` (important)

Apple requires a **Mac** to produce a `.app`. You **cannot** generate `IT Repair & Diagnostic Toolkit.app` from Windows.

| Myth | Reality |
|------|---------|
| Clicking **Yes** on the EXE when Platform = macOS builds the `.app` | **No.** Yes only browses the macOS catalog on Windows with Python. |
| `Build-MacApp.sh` works on Windows | **No.** That script runs **only on macOS**. |
| The EXE can compile the Mac app | **No.** The EXE can only **detect** if `.app` already exists and skip the “first time” warning. |

### Option A — Build on a Mac (once)

```bash
cd /path/to/IT-Repair-Scripts
chmod +x Build-MacApp.sh
zsh Build-MacApp.sh
```

Output: `IT Repair & Diagnostic Toolkit.app` in the toolkit root (same folder as the Windows `.exe`).

### Option B — No Mac nearby

You need access to a Mac (physical, borrowed, or cloud Mac) to run Option A once. There is no Windows-side way to produce the `.app`.

### After the `.app` exists

- Copy **`IT Repair & Diagnostic Toolkit.app` + `Windows/` + `macOS/`** to helpdesk Macs.
- Technicians open the `.app` — **no Python install**.
- On Windows, if the EXE finds `IT Repair & Diagnostic Toolkit.app` in the root, the “FIRST TIME” build warning is **skipped**.

---

## Exit codes (Intune / Jamf)

| Code | Meaning |
|------|---------|
| `0` | Success (warnings may still be logged) |
| `1` | Failure |

---

## Security notes

- Prefer interactive password prompts; avoid `USER_PASSWORD` / `CERT_PASSWORD` in env/argv on shared hosts.
- `trustRoot` certificate install requires `TRUST_ROOT=YES` **and** `CONFIRM=YES`.
- Review [RISK-INVENTORY.md](RISK-INVENTORY.md) before running Dangerous scripts.
- Toolkit binaries are **not Authenticode-signed** by default — pin via AppLocker / Gatekeeper policy in enterprise.

---

## License

Proprietary — see [LICENSE](LICENSE). Third-party tools under nested `_Tools` (Imported Tech Support Tools) keep their own licenses.
