#!/bin/zsh
# IT Repair & Diagnostic Toolkit — macOS launcher
# Prefers IT Repair & Diagnostic Toolkit.app (no Python). Falls back to python3 for builders.
# Double-click in Finder (or: open IT Repair & Diagnostic Toolkit-macOS.command)
cd "$(dirname "$0")" || exit 1

APP="./IT Repair & Diagnostic Toolkit.app"
GUI_BIN="$APP/Contents/MacOS/IT Repair & Diagnostic Toolkit"
PY_GUI="./MASTER-MENU-GUI.py"

# 1) Bundled app — technicians do NOT need Python
if [[ -x "$GUI_BIN" ]]; then
  exec "$GUI_BIN" --platform macOS --style macos
fi
if [[ -d "$APP" ]]; then
  # open(1) if binary path differs slightly between PyInstaller versions
  exec open -n "$APP" --args --platform macOS --style macos
fi

# 2) Dev / pre-build fallback — needs Python 3 + tkinter
if [[ ! -f "$PY_GUI" ]]; then
  osascript -e 'display alert "IT Repair & Diagnostic Toolkit" message "IT Repair & Diagnostic Toolkit.app not found.\n\nOn a Mac with Python, run:\n  zsh Build-MacApp.sh\n\nThen distribute the .app next to Windows/ and macOS/." as critical'
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  osascript -e 'display alert "IT Repair & Diagnostic Toolkit" message "IT Repair & Diagnostic Toolkit.app is missing and Python 3 is not installed.\n\nBuild the app once on a Mac:\n  zsh Build-MacApp.sh\n\nOr install Python from python.org (includes Tk)." as critical'
  exit 1
fi

if ! python3 -c "import tkinter" 2>/dev/null; then
  osascript -e 'display alert "IT Repair & Diagnostic Toolkit" message "Python tkinter is missing.\n\nPrefer building IT Repair & Diagnostic Toolkit.app:\n  zsh Build-MacApp.sh" as critical'
  exit 1
fi

exec python3 "$PY_GUI" --platform macOS --style macos
