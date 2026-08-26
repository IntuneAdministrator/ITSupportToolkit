#!/bin/zsh
# Detection helper — exit 0 + output = installed; exit 1 = not installed.
set -uo pipefail

APP="/Library/Application Support/IT Repair & Diagnostic Toolkit/IT Repair & Diagnostic Toolkit.app"
BIN="$APP/Contents/MacOS/IT Repair & Diagnostic Toolkit"

if [[ -x "$BIN" ]] || [[ -d "$APP" ]]; then
  echo "IT Repair & Diagnostic Toolkit detected"
  exit 0
fi
exit 1
