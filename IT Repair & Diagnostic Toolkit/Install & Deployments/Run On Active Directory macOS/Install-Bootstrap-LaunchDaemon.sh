#!/bin/zsh
# Optional: install a LaunchDaemon that runs Computer-Startup.sh at boot.
# Edit SHARE_UNC below to your SMB path, then:
#   sudo zsh "Install & Deployments/Run On Active Directory macOS/Install-Bootstrap-LaunchDaemon.sh"
#
# The daemon mounts the share (guest or Kerberos as available), runs the
# idempotent install, then unmounts. Adjust credentials policy for your AD.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Run as root (sudo)." >&2
  exit 1
fi

# --- edit for your environment ---
SHARE_UNC="//fileserver.contoso.com/IT-Repair-Scripts"
MOUNT_POINT="/Volumes/IT-Repair-Scripts"
# ---------------------------------

WRAPPER="/Library/Application Support/IT Repair & Diagnostic Toolkit-Bootstrap/run-bootstrap.sh"
PLIST="/Library/LaunchDaemons/com.allesterpadovani.itreapair.bootstrap.plist"

/bin/mkdir -p "$(dirname "$WRAPPER")"

/bin/cat > "$WRAPPER" <<EOF
#!/bin/zsh
set -uo pipefail
SHARE_UNC="$SHARE_UNC"
MOUNT_POINT="$MOUNT_POINT"
STARTUP="\$MOUNT_POINT/Install & Deployments/Run On Active Directory macOS/Computer-Startup.sh"

/bin/mkdir -p "\$MOUNT_POINT"
if ! /sbin/mount | /usr/bin/grep -q " on \$MOUNT_POINT "; then
  /sbin/mount_smbfs "\$SHARE_UNC" "\$MOUNT_POINT" 2>/dev/null || exit 0
  MOUNTED_BY_US=1
else
  MOUNTED_BY_US=0
fi

if [[ -f "\$STARTUP" ]]; then
  /bin/zsh "\$STARTUP" || true
fi

if [[ "\$MOUNTED_BY_US" -eq 1 ]]; then
  /sbin/umount "\$MOUNT_POINT" 2>/dev/null || true
fi
exit 0
EOF
/bin/chmod 755 "$WRAPPER"

/bin/cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.allesterpadovani.itreapair.bootstrap</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>$WRAPPER</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>3600</integer>
  <key>StandardOutPath</key>
  <string>/var/log/it-repair-diagnostic-toolkit-bootstrap.log</string>
  <key>StandardErrorPath</key>
  <string>/var/log/it-repair-diagnostic-toolkit-bootstrap.log</string>
</dict>
</plist>
PLIST

/bin/chmod 644 "$PLIST"
/bin/launchctl bootout system "$PLIST" 2>/dev/null || true
/bin/launchctl bootstrap system "$PLIST"
/bin/launchctl enable system/com.allesterpadovani.itreapair.bootstrap 2>/dev/null || true

echo "Installed LaunchDaemon: $PLIST"
echo "Edit SHARE_UNC in this script and re-run if your share path changes."
echo "Log: /var/log/it-repair-diagnostic-toolkit-bootstrap.log"
exit 0
