#!/bin/zsh
# Removes IT Repair & Diagnostic Toolkit (Intune macOS uninstall / manual).
#   sudo zsh "Install & Deployments/Run On Cloud Intune macOS/Uninstall-Toolkit.sh"
set -uo pipefail

DEST="/Library/Application Support/IT Repair & Diagnostic Toolkit"
LAUNCHER="/Applications/IT Repair & Diagnostic Toolkit.app"

/bin/rm -rf "$LAUNCHER"
/bin/rm -rf "$DEST"

echo "IT Repair & Diagnostic Toolkit removed."
exit 0
