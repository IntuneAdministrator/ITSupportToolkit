#!/bin/zsh
# Detection helper — exit 0 + output = installed; exit 1 = not installed.
# Intune macOS PKG apps usually use file/bundle detection in the admin center;
# this script is for manual checks or custom workflows.
set -uo pipefail

APP="/Library/Application Support/IT Repair & Diagnostic Toolkit/IT Repair & Diagnostic Toolkit.app"
BIN="$APP/Contents/MacOS/IT Repair & Diagnostic Toolkit"

if [[ -x "$BIN" ]] || [[ -d "$APP" ]]; then
  echo "IT Repair & Diagnostic Toolkit detected"
  exit 0
fi
exit 1
