#!/bin/zsh
# Jamf Pro Extension Attribute — Data Type: String
# Settings → Computer Management → Extension Attributes → New
#   Display Name: IT Repair & Diagnostic Toolkit
#   Input Type: Script
#   Inventory display: Operating System (or Extension Attributes)
#
# Returns: Installed | Not Installed
set -uo pipefail

APP="/Library/Application Support/IT Repair & Diagnostic Toolkit/IT Repair & Diagnostic Toolkit.app"
BIN="$APP/Contents/MacOS/IT Repair & Diagnostic Toolkit"

echo "<result>$( [[ -x "$BIN" || -d "$APP" ]] && echo "Installed" || echo "Not Installed" )</result>"
exit 0
