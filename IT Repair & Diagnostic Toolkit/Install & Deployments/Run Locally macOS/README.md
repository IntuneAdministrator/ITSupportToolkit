# Run Locally macOS

Start the toolkit on a Mac without MDM.

## How to run

1. Keep **`Install & Deployments`** inside the toolkit root (next to `Windows/`, `macOS/`, and ideally `IT Repair & Diagnostic Toolkit.app`).
2. Double-click **`Start Toolkit.command`**  
   — or open **`IT Repair & Diagnostic Toolkit.app`** in the toolkit root (preferred; no Python).

If macOS blocks the `.command` the first time: right-click → **Open**, or:

```bash
chmod +x "Install & Deployments/Run Locally macOS/Start Toolkit.command"
xattr -dr com.apple.quarantine "Install & Deployments/Run Locally macOS/Start Toolkit.command"
```

## Notes

- Technicians should use **`IT Repair & Diagnostic Toolkit.app`** (build once with `Build-MacApp.sh`).
- Without the `.app`, this launcher falls back to `python3 MASTER-MENU-GUI.py` (dev / build machine only).
- Cloud deploy: see `Install & Deployments/Run On Cloud Intune macOS/` or `Run On Cloud Jamf macOS/`.
