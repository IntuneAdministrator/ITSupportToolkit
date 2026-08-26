# Run On Cloud Intune macOS

Deploy **IT Repair & Diagnostic Toolkit** to managed Macs via Microsoft Intune (**macOS app (PKG)**).

## What this folder contains

| File | Purpose |
|------|---------|
| `Build-IntunePkg.sh` | **(Mac)** Builds `IT Repair & Diagnostic Toolkit-macOS.pkg` for Intune upload |
| `Install-Toolkit.sh` | Manual / test install (same layout as the PKG) |
| `Uninstall-Toolkit.sh` | Removes install + Applications launcher |
| `Detect-Toolkit.sh` | Optional check (file present = installed) |

## Prerequisites (build machine)

1. A **Mac** (cannot build `.app` or `.pkg` on Windows).
2. Build the GUI once:  
   `zsh Build-MacApp.sh`  
   so `IT Repair & Diagnostic Toolkit.app` exists next to `Windows/` and `macOS/`.
3. Then package:  
   `zsh "Install & Deployments/Run On Cloud Intune macOS/Build-IntunePkg.sh"`

Optional: `-v 1.6.2` and `-o /path/to/out.pkg`.

## Install layout

| Path | Role |
|------|------|
| `/Library/Application Support/IT Repair & Diagnostic Toolkit/` | Full toolkit (`IT Repair & Diagnostic Toolkit.app`, `Windows/`, `macOS/`, menus) |
| `/Applications/IT Repair & Diagnostic Toolkit.app` | Thin launcher → real app under Application Support |

The real `.app` must stay beside `Windows/` and `macOS/` so the catalog resolves correctly.

## Upload to Intune

1. Intune → **Apps** → **All apps** → **Create** → platform **macOS** → **macOS app (PKG)**  
   (preferred for unsigned / complex packages; LOB PKG requires Apple Developer ID Installer signing).
2. Upload `IT Repair & Diagnostic Toolkit-macOS.pkg`.
3. **Detection** (example):  
   Path `/Library/Application Support/IT Repair & Diagnostic Toolkit/IT Repair & Diagnostic Toolkit.app` exists  
   (or use Company Portal / agent rules your tenant uses for PKG apps).
4. Assign to Mac users/devices. App appears in **Company Portal**.

## After install (end user)

**Applications → IT Repair & Diagnostic Toolkit** (launcher).

## Manual install / uninstall (Mac, for testing)

```bash
sudo zsh "Install & Deployments/Run On Cloud Intune macOS/Install-Toolkit.sh"
sudo zsh "Install & Deployments/Run On Cloud Intune macOS/Uninstall-Toolkit.sh"
zsh "Install & Deployments/Run On Cloud Intune macOS/Detect-Toolkit.sh"
```

## Notes

- This path is **macOS / Intune**. Jamf: `Install & Deployments/Run On Cloud Jamf macOS/`. Windows: `Install & Deployments/Run On Cloud Intune Windows\`.
- Gatekeeper may block unsigned apps until your org allows them (PPPC / allowed team ID / notarization as policy requires).
- Exit `0` = success; non-zero = failure (see root `README.md`).
