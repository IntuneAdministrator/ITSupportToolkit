#!/bin/zsh
# Idempotent startup helper for domain Macs (analogous to Windows Computer-Startup.cmd).
# Installs only when the toolkit is missing. Must run as root with the share mounted
# (or with this folder already on local disk next to the full toolkit).
#
# Examples:
#   sudo zsh "/Volumes/IT-Repair-Scripts/Install & Deployments/Run On Active Directory macOS/Computer-Startup.sh"
#   Or install the optional LaunchDaemon (see Install-Bootstrap-LaunchDaemon.sh).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Run as root (sudo)." >&2
  exit 1
fi

zsh "$SCRIPT_DIR/Detect-Toolkit.sh"
if [[ $? -eq 0 ]]; then
  exit 0
fi

zsh "$SCRIPT_DIR/Install-Toolkit.sh"
exit $?
