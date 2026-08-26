#!/bin/zsh
# Removes IT Repair & Diagnostic Toolkit (AD share / ARD / SSH cleanup).
#   sudo zsh "Install & Deployments/Run On Active Directory macOS/Uninstall-Toolkit.sh"
set -uo pipefail

DEST="/Library/Application Support/IT Repair & Diagnostic Toolkit"
LAUNCHER="/Applications/IT Repair & Diagnostic Toolkit.app"
PLIST="/Library/LaunchDaemons/com.allesterpadovani.itreapair.bootstrap.plist"

if [[ -f "$PLIST" ]]; then
  /bin/launchctl bootout system "$PLIST" 2>/dev/null || true
  /bin/rm -f "$PLIST"
fi

/bin/rm -rf "$LAUNCHER"
/bin/rm -rf "$DEST"

echo "IT Repair & Diagnostic Toolkit removed."
exit 0
