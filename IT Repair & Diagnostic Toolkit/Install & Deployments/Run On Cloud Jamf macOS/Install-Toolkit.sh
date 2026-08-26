#!/bin/zsh
# Installs IT Repair & Diagnostic Toolkit for Jamf Pro (per-machine).
# Prefer packaging with Build-JamfPkg.sh and uploading the .pkg to Jamf.
#   sudo zsh "Install & Deployments/Run On Cloud Jamf macOS/Install-Toolkit.sh"
set -euo pipefail

TOOLKIT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="/Library/Application Support/IT Repair & Diagnostic Toolkit"
APP_SRC="$TOOLKIT_ROOT/IT Repair & Diagnostic Toolkit.app"
LAUNCHER="/Applications/IT Repair & Diagnostic Toolkit.app"
LOCAL_CMD="Install & Deployments/Run Locally macOS/Start Toolkit.command"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Install on macOS only." >&2
  exit 1
fi

if [[ ! -d "$APP_SRC" ]]; then
  echo "ERROR: IT Repair & Diagnostic Toolkit.app not found at: $APP_SRC" >&2
  echo "Build once on a Mac: zsh Build-MacApp.sh" >&2
  exit 1
fi

COPY_NAMES=(
  "IT Repair & Diagnostic Toolkit.app"
  "MASTER-MENU.ps1"
  "MASTER-MENU-GUI.py"
  "Windows"
  "macOS"
  "README.md"
  "LICENSE"
  "RISK-INVENTORY.md"
  "IT Repair & Diagnostic Toolkit-macOS.command"
  "Build-MacApp.sh"
  "Install & Deployments/Run Locally macOS"
)

/bin/mkdir -p "$DEST"

for name in "${COPY_NAMES[@]}"; do
  src="$TOOLKIT_ROOT/$name"
  [[ -e "$src" ]] || continue
  target="$DEST/$name"
  /bin/mkdir -p "$(dirname "$target")"
  if [[ -d "$src" ]]; then
    /bin/rm -rf "$target"
    /bin/cp -R "$src" "$target"
  else
    /bin/cp -f "$src" "$target"
  fi
done

/bin/rm -rf "$LAUNCHER"
/bin/mkdir -p "$LAUNCHER/Contents/MacOS"
/bin/cat > "$LAUNCHER/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>IT Repair &amp; Diagnostic Toolkit</string>
  <key>CFBundleIdentifier</key>
  <string>com.allesterpadovani.itreapair.launcher</string>
  <key>CFBundleName</key>
  <string>IT Repair &amp; Diagnostic Toolkit</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.6.2</string>
  <key>CFBundleVersion</key>
  <string>1.6.2</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

/bin/cat > "$LAUNCHER/Contents/MacOS/IT Repair & Diagnostic Toolkit" <<'LAUNCH'
#!/bin/zsh
REAL="/Library/Application Support/IT Repair & Diagnostic Toolkit/IT Repair & Diagnostic Toolkit.app"
BIN="$REAL/Contents/MacOS/IT Repair & Diagnostic Toolkit"
if [[ -x "$BIN" ]]; then
  exec "$BIN" --platform macOS --style macos "$@"
fi
if [[ -d "$REAL" ]]; then
  exec open -n "$REAL" --args --platform macOS --style macos "$@"
fi
osascript -e 'display alert "IT Repair & Diagnostic Toolkit" message "Installed app not found under Application Support." as critical'
exit 1
LAUNCH
/bin/chmod 755 "$LAUNCHER/Contents/MacOS/IT Repair & Diagnostic Toolkit"

[[ -f "$DEST/IT Repair & Diagnostic Toolkit-macOS.command" ]] && /bin/chmod 755 "$DEST/IT Repair & Diagnostic Toolkit-macOS.command"
[[ -f "$DEST/Build-MacApp.sh" ]] && /bin/chmod 755 "$DEST/Build-MacApp.sh"
[[ -f "$DEST/$LOCAL_CMD" ]] && /bin/chmod 755 "$DEST/$LOCAL_CMD"
/usr/bin/find "$DEST/macOS" -type f \( -name "*.sh" -o -name "*.command" \) -exec /bin/chmod 755 {} + 2>/dev/null || true

/usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
/usr/bin/xattr -dr com.apple.quarantine "$LAUNCHER" 2>/dev/null || true

echo "Installed to $DEST"
echo "Launcher: $LAUNCHER"
exit 0
