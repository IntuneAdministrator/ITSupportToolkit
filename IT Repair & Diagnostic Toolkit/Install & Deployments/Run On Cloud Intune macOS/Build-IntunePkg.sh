#!/bin/zsh
# ============================================================
# Build IT Repair & Diagnostic Toolkit.pkg for Microsoft Intune (macOS PKG app).
# Run ONCE on a Mac after IT Repair & Diagnostic Toolkit.app exists.
# Output: IT Repair & Diagnostic Toolkit-macOS.pkg next to this script (or -o path).
# Author: Allester Padovani
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION="1.6.2"
IDENTIFIER="com.allesterpadovani.itreapair"
OUT_PKG="$SCRIPT_DIR/IT Repair & Diagnostic Toolkit-macOS.pkg"

while getopts "o:v:" opt; do
  case "$opt" in
    o) OUT_PKG="$OPTARG" ;;
    v) VERSION="$OPTARG" ;;
    *) echo "Usage: $0 [-v version] [-o output.pkg]"; exit 2 ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: Build the Intune .pkg on a Mac." >&2
  exit 1
fi

if [[ ! -d "$TOOLKIT_ROOT/IT Repair & Diagnostic Toolkit.app" ]]; then
  echo "ERROR: IT Repair & Diagnostic Toolkit.app missing in $TOOLKIT_ROOT" >&2
  echo "Run first: zsh Build-MacApp.sh" >&2
  exit 1
fi

STAGE="$(/usr/bin/mktemp -d /tmp/it-repair-intune-XXXXXX)"
PAYLOAD="$STAGE/payload"
SCRIPTS="$STAGE/scripts"
/bin/mkdir -p "$PAYLOAD/Library/Application Support/IT Repair & Diagnostic Toolkit"
/bin/mkdir -p "$SCRIPTS"

echo "==> Staging payload from $TOOLKIT_ROOT"
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

for name in "${COPY_NAMES[@]}"; do
  src="$TOOLKIT_ROOT/$name"
  [[ -e "$src" ]] || continue
  target="$PAYLOAD/Library/Application Support/IT Repair & Diagnostic Toolkit/$name"
  /bin/mkdir -p "$(dirname "$target")"
  /bin/cp -R "$src" "$target"
done

# Applications launcher (same as Install-Toolkit.sh)
LAUNCHER_DIR="$PAYLOAD/Applications/IT Repair & Diagnostic Toolkit.app/Contents"
/bin/mkdir -p "$LAUNCHER_DIR/MacOS"
/bin/cat > "$LAUNCHER_DIR/Info.plist" <<PLIST
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
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

/bin/cat > "$LAUNCHER_DIR/MacOS/IT Repair & Diagnostic Toolkit" <<'LAUNCH'
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
/bin/chmod 755 "$LAUNCHER_DIR/MacOS/IT Repair & Diagnostic Toolkit"

/bin/cat > "$SCRIPTS/postinstall" <<'POST'
#!/bin/zsh
set -euo pipefail
DEST="/Library/Application Support/IT Repair & Diagnostic Toolkit"
LAUNCHER="/Applications/IT Repair & Diagnostic Toolkit.app"
[[ -f "$DEST/IT Repair & Diagnostic Toolkit-macOS.command" ]] && /bin/chmod 755 "$DEST/IT Repair & Diagnostic Toolkit-macOS.command"
[[ -f "$DEST/Build-MacApp.sh" ]] && /bin/chmod 755 "$DEST/Build-MacApp.sh"
[[ -f "$DEST/Install & Deployments/Run Locally macOS/Start Toolkit.command" ]] && /bin/chmod 755 "$DEST/Install & Deployments/Run Locally macOS/Start Toolkit.command"
/usr/bin/find "$DEST/macOS" -type f \( -name "*.sh" -o -name "*.command" \) -exec /bin/chmod 755 {} + 2>/dev/null || true
/usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
/usr/bin/xattr -dr com.apple.quarantine "$LAUNCHER" 2>/dev/null || true
exit 0
POST
/bin/chmod 755 "$SCRIPTS/postinstall"

echo "==> Building $OUT_PKG (version $VERSION)"
/usr/bin/pkgbuild \
  --root "$PAYLOAD" \
  --scripts "$SCRIPTS" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location / \
  "$OUT_PKG"

/bin/rm -rf "$STAGE"

echo ""
echo "Created: $OUT_PKG"
echo "Upload to Intune as: Apps → macOS → macOS app (PKG)"
echo "Detection file (example): /Library/Application Support/IT Repair & Diagnostic Toolkit/IT Repair & Diagnostic Toolkit.app"
echo "Uninstall: assign removal or run Uninstall-Toolkit.sh as root"
echo ""
