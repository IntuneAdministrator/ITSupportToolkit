# Run On Cloud Jamf macOS

Deploy **IT Repair & Diagnostic Toolkit** to managed Macs via **Jamf Pro** (package + policy / Self Service).

## What this folder contains

| File | Purpose |
|------|---------|
| `Build-JamfPkg.sh` | **(Mac)** Builds `IT Repair & Diagnostic Toolkit-Jamf.pkg` for Jamf upload |
| `Install-Toolkit.sh` | Manual / test install (same layout as the PKG) |
| `Uninstall-Toolkit.sh` | Upload as a Jamf **Script** for uninstall policies |
| `Detect-Toolkit.sh` | Optional local check |
| `Extension-Attribute-Installed.sh` | Jamf **Extension Attribute** (`Installed` / `Not Installed`) |

## Prerequisites (build machine)

1. A **Mac** (cannot build `.app` or `.pkg` on Windows).
2. Build the GUI once:  
   `zsh Build-MacApp.sh`
3. Package for Jamf:  
   `zsh "Install & Deployments/Run On Cloud Jamf macOS/Build-JamfPkg.sh"`

Optional: `-v 1.6.2` and `-o /path/to/out.pkg`.

## Install layout

| Path | Role |
|------|------|
| `/Library/Application Support/IT Repair & Diagnostic Toolkit/` | Full toolkit |
| `/Applications/IT Repair & Diagnostic Toolkit.app` | Thin launcher |

Same layout as Intune macOS / Active Directory macOS under `Install & Deployments/`.

## Upload to Jamf Pro

### 1) Package

1. **Settings → Computer Management → Packages → New**
2. Upload `IT Repair & Diagnostic Toolkit-Jamf.pkg`
3. Display name e.g. **IT Repair & Diagnostic Toolkit**

### 2) Install policy

1. **Computers → Policies → New**
2. **Packages** → add the package (Action: Install)
3. **Scope** → target smart/static groups (helpdesk Macs, etc.)
4. Optional: **Self Service** → enable so technicians can install from Self Service
5. Trigger: Recurring Check-in and/or Self Service

### 3) Uninstall policy (optional)

1. **Settings → Computer Management → Scripts → New**  
   Paste contents of `Uninstall-Toolkit.sh` (or upload the file).
2. Policy → **Scripts** → that script (Priority: After is fine; no package needed).
3. Scope narrowly (or Self Service “Remove IT Repair & Diagnostic Toolkit”).

### 4) Extension Attribute (inventory)

1. **Settings → Computer Management → Extension Attributes → New**
2. Input Type: **Script** — paste `Extension-Attribute-Installed.sh`
3. Data Type: **String**
4. After inventory update, smart group example:  
   `IT Repair & Diagnostic Toolkit` **is** `Installed`

## After install (end user)

**Applications → IT Repair & Diagnostic Toolkit**, or Self Service if you enabled it.

## Manual test (Mac)

```bash
sudo zsh "Install & Deployments/Run On Cloud Jamf macOS/Install-Toolkit.sh"
sudo zsh "Install & Deployments/Run On Cloud Jamf macOS/Uninstall-Toolkit.sh"
zsh "Install & Deployments/Run On Cloud Jamf macOS/Detect-Toolkit.sh"
```

## Notes

- This path is **macOS / Jamf Pro**. Intune: `Install & Deployments/Run On Cloud Intune macOS/`. On-prem share: `Install & Deployments/Run On Active Directory macOS/`.
- Sign/notarize the PKG if your Jamf/Gatekeeper policy requires it (Apple Developer ID Installer).
- Exit `0` = success; non-zero = failure (see root `README.md`).
