#!/bin/zsh
# Prefer double-clicking IT Repair & Diagnostic Toolkit.app in the toolkit root when present.
# This .command is a Finder-friendly fallback (same idea as Start Toolkit.bat on Windows).
cd "$(dirname "$0")/../.." || exit 1

APP="./IT Repair & Diagnostic Toolkit.app"
GUI_BIN="$APP/Contents/MacOS/IT Repair & Diagnostic Toolkit"
PY_GUI="./MASTER-MENU-GUI.py"

if [[ -x "$GUI_BIN" ]]; then
  exec "$GUI_BIN" --platform macOS --style macos
fi
if [[ -d "$APP" ]]; then
  exec open -n "$APP" --args --platform macOS --style macos
fi

if [[ ! -f "$PY_GUI" ]]; then
  osascript -e 'display alert "IT Repair & Diagnostic Toolkit" message "IT Repair & Diagnostic Toolkit.app not found in the toolkit folder.\n\nBuild once on a Mac:\n  zsh Build-MacApp.sh" as critical'
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  osascript -e 'display alert "IT Repair & Diagnostic Toolkit" message "IT Repair & Diagnostic Toolkit.app is missing and Python 3 is not installed.\n\nBuild the app:\n  zsh Build-MacApp.sh" as critical'
  exit 1
fi

if ! python3 -c "import tkinter" 2>/dev/null; then
  osascript -e 'display alert "IT Repair & Diagnostic Toolkit" message "Python tkinter is missing.\n\nPrefer building IT Repair & Diagnostic Toolkit.app first." as critical'
  exit 1
fi

exec python3 "$PY_GUI" --platform macOS --style macos
