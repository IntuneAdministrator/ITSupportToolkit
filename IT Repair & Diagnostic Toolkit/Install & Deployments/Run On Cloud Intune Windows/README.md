# Run On Cloud Intune Windows

Deploy **IT Repair & Diagnostic Toolkit** as a Win32 app in Microsoft Intune (Company Portal).

## What this folder contains

| File | Purpose |
|------|---------|
| `Install-Toolkit.ps1` / `Install.cmd` | Copies toolkit to `%ProgramFiles%\IT Repair & Diagnostic Toolkit` + Start Menu shortcut |
| `Uninstall-Toolkit.ps1` / `Uninstall.cmd` | Removes install + shortcut |
| `Detect-Toolkit.ps1` | Intune detection (file present = installed) |

## Package with Win32 Content Prep Tool

1. Keep the **entire** toolkit folder as the source (parent of `Install & Deployments`), including `Windows\`, `macOS\`, `IT Repair & Diagnostic Toolkit.exe`, menus, etc.
2. Run [Microsoft Win32 Content Prep Tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool):
   ```text
   IntuneWinAppUtil.exe -c "<path>\IT-Repair-Scripts" -s "Install & Deployments\Run On Cloud Intune Windows\Install.cmd" -o "<output-folder>"
   ```
3. In Intune → **Apps** → **Windows** → **Win32**:
   - Upload the `.intunewin`
   - **Install command:**  
     `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Install & Deployments\Run On Cloud Intune Windows\Install-Toolkit.ps1"`  
     (or `Install & Deployments\Run On Cloud Intune Windows\Install.cmd`)
   - **Uninstall command:**  
     `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Install & Deployments\Run On Cloud Intune Windows\Uninstall-Toolkit.ps1"`
   - **Install behavior:** System
   - **Detection:** Use custom script `Detect-Toolkit.ps1` (64-bit)  
     or file detection:  
     `%ProgramFiles%\IT Repair & Diagnostic Toolkit\IT Repair & Diagnostic Toolkit.exe`
4. Assign to users/devices. App appears in **Company Portal**.

## After install (end user)

Start Menu → **IT Repair & Diagnostic Toolkit** → opens `IT Repair & Diagnostic Toolkit.exe`.

## Notes

- This path is **Windows / Intune only**. For Macs use `Install & Deployments\Run On Cloud Intune macOS\`.
- Exit `0` = success; non-zero = failure (see root `README.md`).
- Unsigned EXE may trigger SmartScreen — use your org’s code signing / AppLocker policy in production.
