#!/bin/zsh
# Removes IT Repair & Diagnostic Toolkit (Jamf policy script or manual).
# Paste into Jamf Pro → Settings → Computer Management → Scripts, or:
#   sudo zsh "Install & Deployments/Run On Cloud Jamf macOS/Uninstall-Toolkit.sh"
set -uo pipefail

DEST="/Library/Application Support/IT Repair & Diagnostic Toolkit"
LAUNCHER="/Applications/IT Repair & Diagnostic Toolkit.app"

/bin/rm -rf "$LAUNCHER"
/bin/rm -rf "$DEST"

echo "IT Repair & Diagnostic Toolkit removed."
exit 0
