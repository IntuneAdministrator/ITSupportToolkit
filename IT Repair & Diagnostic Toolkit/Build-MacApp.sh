#!/bin/zsh
# ============================================================
# Build IT Repair & Diagnostic Toolkit.app (macOS) — no Python required for end users
# Run this ONCE on a Mac that has Python 3 + pip.
# Output: IT Repair & Diagnostic Toolkit.app next to Windows/ and macOS/
# Author: Allester Padovani
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Build the Mac .app on a Mac (cannot cross-compile from Windows/Linux)."
  exit 1
fi

if [[ ! -f "$ROOT/MASTER-MENU-GUI.py" ]]; then
  echo "ERROR: MASTER-MENU-GUI.py not found in $ROOT"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 required to build. Install from https://www.python.org/downloads/"
  exit 1
fi

if ! python3 -c "import tkinter" 2>/dev/null; then
  echo "ERROR: tkinter missing. Use the python.org installer (includes Tk)."
  exit 1
fi

echo "==> Installing PyInstaller (build machine only)..."
python3 -m pip install --upgrade pip pyinstaller >/dev/null

DIST="$ROOT/dist-mac"
BUILD="$ROOT/build-mac"
APP_NAME="IT Repair & Diagnostic Toolkit"
rm -rf "$DIST" "$BUILD" "$ROOT/$APP_NAME.app"

echo "==> Building $APP_NAME.app (windowed, bundles Python+Tk)..."
python3 -m PyInstaller \
  --noconfirm \
  --clean \
  --windowed \
  --name "$APP_NAME" \
  --osx-bundle-identifier "com.allesterpadovani.itreapair" \
  --distpath "$DIST" \
  --workpath "$BUILD" \
  --specpath "$BUILD" \
  "$ROOT/MASTER-MENU-GUI.py"

if [[ ! -d "$DIST/$APP_NAME.app" ]]; then
  echo "ERROR: PyInstaller did not produce $DIST/$APP_NAME.app"
  exit 1
fi

mv "$DIST/$APP_NAME.app" "$ROOT/$APP_NAME.app"
rm -rf "$DIST" "$BUILD"

# Make sure scripts folders are visible beside the app
for d in Windows macOS; do
  if [[ ! -d "$ROOT/$d" ]]; then
    echo "WARN: $d/ not found next to the .app — catalog will be empty until folders are present."
  fi
done

echo ""
echo "Created: $ROOT/$APP_NAME.app"
echo "Keep this .app next to Windows/ and macOS/ (same layout as the Windows .exe)."
echo "End users: double-click IT Repair & Diagnostic Toolkit.app — no Python install needed."
echo "Optional: double-click IT Repair & Diagnostic Toolkit-macOS.command (prefers the .app)."
echo ""
