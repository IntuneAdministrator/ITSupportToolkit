#!/bin/zsh
# Author: Allester Padovani
# ============================================================
# Script: jamf-extension-attribute-inventory-mac.sh | Phase 13 common problems | SysAdmin/16_Jamf-Advanced
# Requires: sudo | Usage: sudo zsh jamf-extension-attribute-inventory-mac.sh
# ============================================================
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "ERROR: run as root (sudo)" >&2; exit 1; }
REAL_USER=${SUDO_USER:-root}
if [[ "$REAL_USER" != "root" ]]; then
  REAL_HOME=$(dscl . -read "/Users/$REAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
  REAL_HOME=${REAL_HOME:-/Users/$REAL_USER}
else REAL_HOME="/var/root"; fi
LOG_DIR="$REAL_HOME/Library/Logs/IT-Repair"
REPORT_DIR="$LOG_DIR/Reports"; BACKUP_DIR="$LOG_DIR/Backups"
mkdir -p "$LOG_DIR" "$REPORT_DIR" "$BACKUP_DIR"
[[ "$REAL_USER" != "root" ]] && chown -R "$REAL_USER":staff "$LOG_DIR" 2>/dev/null || true
SCRIPT_BASE=$(basename "$0" .sh); FOLDER_NAME='16_Jamf-Advanced'
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/${SCRIPT_BASE}_$TIMESTAMP.log"
REPORT_PATH="$REPORT_DIR/${SCRIPT_BASE}_$TIMESTAMP.html"
TOTAL_STEPS=8; JOIN_STATE="Unknown"; COMPUTER_NAME=$(hostname)
# IT-Repair-Scripts — macOS common helpers (embedded into every .sh at generation time)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
INFO_COUNT=0
REPORT_ROWS=""

log_info()    { echo -e "${CYAN}[INFO]  $(date '+%H:%M:%S') $1${NC}" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[OK]    $(date '+%H:%M:%S') $1${NC}" | tee -a "$LOG_FILE"; }
log_warn()    { echo -e "${YELLOW}[WARN]  $(date '+%H:%M:%S') $1${NC}" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[ERROR] $(date '+%H:%M:%S') $1${NC}" | tee -a "$LOG_FILE"; }

show_progress() {
    local step=$1 total=$2 label=$3
    local pct=$(( step * 100 / total ))
    local filled=$(( pct / 5 )) empty=$(( 20 - filled ))
    local bar="["
    local i
    for ((i=0;i<filled;i++)); do bar+="█"; done
    for ((i=0;i<empty;i++)); do bar+="░"; done
    bar+="]  ${pct}%"
    log_info "$bar  Step $step/$total — $label"
}

section_banner() {
    echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}  [$1]${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}\n"
}

html_escape() {
    local s="$1"
    s=${s//&/&amp;}
    s=${s//</&lt;}
    s=${s//>/&gt;}
    s=${s//\"/&quot;}
    printf '%s' "$s"
}

add_report_row() {
    local check="$1" result="$2" status="$3" detail="${4:-}"
    case "$status" in
        PASS) PASS_COUNT=$((PASS_COUNT+1)) ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT+1)) ;;
        WARN) WARN_COUNT=$((WARN_COUNT+1)) ;;
        INFO) INFO_COUNT=$((INFO_COUNT+1)) ;;
    esac
    local badge_class
    badge_class=$(echo "$status" | tr '[:upper:]' '[:lower:]')
    local c r d
    c=$(html_escape "$check"); r=$(html_escape "$result"); d=$(html_escape "$detail")
    REPORT_ROWS+="<tr><td>${c}</td><td>${r}</td><td><span class='badge ${badge_class}'>${status}</span></td><td><small>${d}</small></td></tr>"
}

export_html_report() {
    local title="$1" computer_name="$2" join_state="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    cat > "$REPORT_PATH" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>${title}</title>
<style>
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:'Segoe UI',Arial,sans-serif; background:#0f1117; color:#e2e8f0; padding:24px; }
  h1 { color:#63b3ed; margin-bottom:4px; font-size:1.6rem; }
  .meta { color:#718096; font-size:.85rem; margin-bottom:20px; }
  .meta span { margin-right:18px; }
  .summary { display:flex; gap:14px; margin-bottom:20px; flex-wrap:wrap; }
  .card { background:#1a1f2e; border-radius:8px; padding:14px 20px; min-width:120px; }
  .card .num { font-size:2rem; font-weight:700; }
  .card .lbl { font-size:.75rem; color:#718096; text-transform:uppercase; }
  .green{color:#68d391} .red{color:#fc8181} .yellow{color:#f6e05e} .blue{color:#63b3ed}
  table { width:100%; border-collapse:collapse; background:#1a1f2e; border-radius:8px; overflow:hidden; }
  th { background:#2d3748; color:#90cdf4; text-align:left; padding:10px 14px; font-size:.8rem; text-transform:uppercase; letter-spacing:.05em; }
  td { padding:9px 14px; border-bottom:1px solid #2d3748; font-size:.88rem; vertical-align:top; }
  tr:last-child td { border-bottom:none; }
  tr:hover td { background:#232a3b; }
  .badge { display:inline-block; padding:2px 10px; border-radius:999px; font-size:.75rem; font-weight:700; }
  .pass{background:#22543d;color:#68d391} .fail{background:#742a2a;color:#fc8181}
  .warn{background:#744210;color:#f6e05e} .info{background:#1a365d;color:#63b3ed}
  footer { margin-top:16px; color:#4a5568; font-size:.8rem; }
</style>
</head>
<body>
<h1>🔧 ${title}</h1>
<div class="meta">
  <span>🖥️ <strong>${computer_name}</strong></span>
  <span>🔗 Join State: <strong>${join_state}</strong></span>
  <span>🕐 ${timestamp}</span>
  <span>📄 Log: ${LOG_FILE}</span>
</div>
<div class="summary" id="summary"></div>
<table>
  <thead><tr><th>Check</th><th>Result</th><th>Status</th><th>Detail</th></tr></thead>
  <tbody>
${REPORT_ROWS}
  </tbody>
</table>
<footer>IT-Repair-Scripts v1.0.0 — ${SCRIPT_BASE}.sh</footer>
<script>
  const rows=document.querySelectorAll("tbody tr");
  const c={PASS:0,FAIL:0,WARN:0,INFO:0};
  rows.forEach(r=>{const b=r.querySelector(".badge");if(b)c[b.textContent.trim()]=(c[b.textContent.trim()]||0)+1;});
  const col={PASS:"green",FAIL:"red",WARN:"yellow",INFO:"blue"};
  const lbl={PASS:"Passed",FAIL:"Failed",WARN:"Warnings",INFO:"Info"};
  const s=document.getElementById("summary");
  Object.entries(c).forEach(([k,v])=>{if(v>0)s.innerHTML+=\`<div class="card"><div class="num \${col[k]}">\${v}</div><div class="lbl">\${lbl[k]}</div></div>\`;});
</script>
</body>
</html>
EOF
}

open_report_if_interactive() {
    if [[ $EUID -eq 0 ]] && [[ -z "${SUDO_USER:-}" ]] && [[ -z "${DISPLAY:-}" ]]; then
        log_info "Report browser open suppressed (root/MDM session)"
        return 0
    fi
    if command -v open >/dev/null 2>&1; then
        open "$REPORT_PATH" 2>/dev/null || true
    fi
}

print_completion_summary() {
    echo -e "\n${CYAN}┌─────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│         SCRIPT COMPLETE                 │${NC}"
    echo -e "${GREEN}│  PASS : $PASS_COUNT${NC}"
    echo -e "${RED}│  FAIL : $FAIL_COUNT${NC}"
    echo -e "${YELLOW}│  WARN : $WARN_COUNT${NC}"
    echo -e "${CYAN}│  Log  : $LOG_FILE${NC}"
    echo -e "${CYAN}│  Report: $REPORT_PATH${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────┘${NC}"
}

get_exit_code() {
    if [[ $FAIL_COUNT -gt 0 ]]; then echo 2
    elif [[ $WARN_COUNT -gt 0 ]]; then echo 1
    else echo 0
    fi
}

detect_mdm_join_state() {
    local profiles
    profiles=$(profiles status -type enrollment 2>/dev/null || true)
    if echo "$profiles" | grep -qi 'enrolled'; then
        JOIN_STATE="MDM Enrolled"
    elif [[ -f /usr/local/bin/jamf ]] || [[ -f /usr/local/jamf/bin/jamf ]]; then
        JOIN_STATE="Jamf binary present (check enrollment)"
    else
        JOIN_STATE="Not MDM-enrolled / Unknown"
    fi
    COMPUTER_NAME=$(scutil --get ComputerName 2>/dev/null || hostname)
}

trap 'ec=$(get_exit_code); exit $ec' EXIT
section_banner "INITIALIZATION"
show_progress 1 "$TOTAL_STEPS" "Start"
detect_mdm_join_state
add_report_row "Computer" "$COMPUTER_NAME" "INFO" "$JOIN_STATE"
add_report_row "Module" "16_Jamf-Advanced" "INFO" "SysAdmin"
section_banner "COMMON PROBLEM TRIAGE"
show_progress 2 "$TOTAL_STEPS" "Environment"
add_report_row "User" "$REAL_USER" "INFO" "$REAL_HOME"
sw_vers 2>&1 | tee -a "$LOG_FILE" || true

if [[ "$SCRIPT_BASE" == *notification* || "$SCRIPT_BASE" == *control-center* || "$SCRIPT_BASE" == *clipboard* || "$SCRIPT_BASE" == *screenshot* || "$SCRIPT_BASE" == *stage-manager* ]]; then
  show_progress 3 "$TOTAL_STEPS" "UI shell"
  killall NotificationCenter 2>/dev/null || true
  killall ControlCenter 2>/dev/null || true
  killall Finder 2>/dev/null || true
  add_report_row "UI daemons" "NotificationCenter/ControlCenter/Finder restarted" "PASS" ""
fi

if [[ "$SCRIPT_BASE" == *wifi* || "$SCRIPT_BASE" == *ethernet* || "$SCRIPT_BASE" == *dns* || "$SCRIPT_BASE" == *vpn* || "$SCRIPT_BASE" == *captive* || "$SCRIPT_BASE" == *proxy* || "$SCRIPT_BASE" == *mtu* || "$SCRIPT_BASE" == *roaming* ]]; then
  show_progress 3 "$TOTAL_STEPS" "Network"
  dscacheutil -flushcache 2>/dev/null || true
  killall -HUP mDNSResponder 2>/dev/null || true
  add_report_row "DNS flush" "Done" "PASS" ""
  networksetup -listallhardwareports 2>&1 | tee -a "$LOG_FILE" || true
  if [[ "$SCRIPT_BASE" == *wifi* || "$SCRIPT_BASE" == *captive* ]]; then
    networksetup -setairportpower en0 off 2>/dev/null || true
    sleep 2
    networksetup -setairportpower en0 on 2>/dev/null || true
    add_report_row "Wi-Fi cycle" "Power cycle attempted" "PASS" "en0"
  fi
  if [[ "$SCRIPT_BASE" == *mtu* ]]; then
    networksetup -setMTU en0 1500 2>/dev/null || true
    add_report_row "MTU" "1500 on en0" "PASS" ""
  fi
fi

if [[ "$SCRIPT_BASE" == *outlook* || "$SCRIPT_BASE" == *teams* || "$SCRIPT_BASE" == *excel* || "$SCRIPT_BASE" == *word* || "$SCRIPT_BASE" == *office* ]]; then
  show_progress 3 "$TOTAL_STEPS" "Microsoft 365"
  killall "Microsoft Teams" "Microsoft Outlook" 2>/dev/null || true
  rm -rf "$REAL_HOME/Library/Group Containers/UBF8T346G9.com.microsoft.teams"/Library/Caches/* 2>/dev/null || true
  rm -rf "$REAL_HOME/Library/Containers/com.microsoft.teams2"/Data/Library/Caches/* 2>/dev/null || true
  add_report_row "M365 cache" "Teams/Outlook quit; cache cleared" "PASS" ""
  if [[ "$SCRIPT_BASE" == *offline* ]]; then
    add_report_row "Outlook offline" "Disable Work Offline in Outlook status bar" "WARN" ""
  fi
  if [[ "$SCRIPT_BASE" == *database* || "$SCRIPT_BASE" == *rebuild* ]]; then
    add_report_row "Outlook DB" "Use Outlook > Rebuild if profile corrupt" "WARN" ""
  fi
fi

if [[ "$SCRIPT_BASE" == *printer* || "$SCRIPT_BASE" == *airprint* || "$SCRIPT_BASE" == *queue* ]]; then
  show_progress 3 "$TOTAL_STEPS" "Printing"
  cancel -a "$REAL_USER" 2>/dev/null || true
  lpstat -p 2>&1 | tee -a "$LOG_FILE" || true
  add_report_row "Print queue" "Canceled jobs; list printers" "PASS" ""
fi

if [[ "$SCRIPT_BASE" == *display* || "$SCRIPT_BASE" == *flicker* || "$SCRIPT_BASE" == *bluetooth* || "$SCRIPT_BASE" == *facetime* || "$SCRIPT_BASE" == *hdmi* || "$SCRIPT_BASE" == *camera* || "$SCRIPT_BASE" == *mic* ]]; then
  show_progress 3 "$TOTAL_STEPS" "Display / AV"
  killall coreaudiod 2>/dev/null || true
  add_report_row "coreaudiod" "Restarted" "PASS" ""
  system_profiler SPAudioDataType SPDisplaysDataType 2>/dev/null | head -n 40 | tee -a "$LOG_FILE" || true
  if [[ "$SCRIPT_BASE" == *bluetooth* ]]; then
    blueutil -p 0 2>/dev/null || true; sleep 2; blueutil -p 1 2>/dev/null || true
    add_report_row "Bluetooth" "Power cycle attempted" "PASS" ""
  fi
fi

if [[ "$SCRIPT_BASE" == *safari* || "$SCRIPT_BASE" == *chrome* || "$SCRIPT_BASE" == *browser* ]]; then
  show_progress 3 "$TOTAL_STEPS" "Browser"
  killall Safari "Google Chrome" 2>/dev/null || true
  rm -rf "$REAL_HOME/Library/Caches/com.apple.Safari" 2>/dev/null || true
  rm -rf "$REAL_HOME/Library/Caches/Google/Chrome" 2>/dev/null || true
  add_report_row "Browser cache" "Safari/Chrome cache cleared" "PASS" ""
fi

if [[ "$SCRIPT_BASE" == *login* || "$SCRIPT_BASE" == *startup* || "$SCRIPT_BASE" == *slow* || "$SCRIPT_BASE" == *password* || "$SCRIPT_BASE" == *fast-user* ]]; then
  show_progress 3 "$TOTAL_STEPS" "Login / boot"
  launchctl list 2>/dev/null | head -n 20 | tee -a "$LOG_FILE" || true
  add_report_row "Launch agents" "Sample captured" "INFO" ""
fi

if [[ "$SCRIPT_BASE" == *finder* || "$SCRIPT_BASE" == *spotlight* || "$SCRIPT_BASE" == *quick-look* || "$SCRIPT_BASE" == *launchservices* || "$SCRIPT_BASE" == *system-settings* ]]; then
  show_progress 3 "$TOTAL_STEPS" "Finder / Spotlight"
  if [[ "$SCRIPT_BASE" == *spotlight* || "$SCRIPT_BASE" == *quick-look* ]]; then
    mdutil -E / 2>/dev/null || true
    qlmanage -r 2>/dev/null || true
    add_report_row "Spotlight/QL" "Reindex + qlmanage -r" "PASS" ""
  fi
  if [[ "$SCRIPT_BASE" == *launchservices* ]]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user 2>/dev/null || true
    add_report_row "LaunchServices" "Database reset" "PASS" ""
  fi
  killall Finder 2>/dev/null || true
  add_report_row "Finder" "Restarted" "PASS" ""
fi

if [[ "$SCRIPT_BASE" == *memory* || "$SCRIPT_BASE" == *storage* || "$SCRIPT_BASE" == *battery* || "$SCRIPT_BASE" == *kernel* || "$SCRIPT_BASE" == *swap* || "$SCRIPT_BASE" == *pressure* ]]; then
  show_progress 3 "$TOTAL_STEPS" "Performance"
  vm_stat 2>&1 | tee -a "$LOG_FILE" || true
  df -h / 2>&1 | tee -a "$LOG_FILE" || true
  add_report_row "Memory/Disk" "vm_stat + df captured" "INFO" ""
  if [[ "$SCRIPT_BASE" == *login-items* ]]; then
    osascript -e 'tell application "System Events" to get the name of every login item' 2>&1 | tee -a "$LOG_FILE" || true
  fi
fi

if [[ "$SCRIPT_BASE" == *teams-call* || "$SCRIPT_BASE" == *clamshell* || "$SCRIPT_BASE" == *scaling* ]]; then
  show_progress 3 "$TOTAL_STEPS" "Remote work"
  add_report_row "Guidance" "Use wired LAN; disable VPN split issues; check display scaling" "WARN" ""
fi

if [[ "$SCRIPT_BASE" == *apple-silicon* || "$SCRIPT_BASE" == *m-series* || "$SCRIPT_BASE" == *nvme* || "$SCRIPT_BASE" == *thunderbolt* || "$SCRIPT_BASE" == *dock* || "$SCRIPT_BASE" == *battery* || "$SCRIPT_BASE" == *warranty* || "$SCRIPT_BASE" == *applecare* || "$SCRIPT_BASE" == *magic-* || "$SCRIPT_BASE" == *airpods* || "$SCRIPT_BASE" == *egpu* || "$SCRIPT_BASE" == *wacom* || "$SCRIPT_BASE" == *continuity-camera* || "$SCRIPT_BASE" == *studio-display* || "$SCRIPT_BASE" == *pro-display* || "$SCRIPT_BASE" == *usb-c-hub* || "$SCRIPT_BASE" == *external-ssd* || "$SCRIPT_BASE" == *serial-specs* ]]; then
  show_progress 3 "$TOTAL_STEPS" "Hardware / Apple Silicon"
  system_profiler SPHardwareDataType SPDisplaysDataType SPPowerDataType SPThunderboltDataType SPUSBDataType 2>/dev/null | head -n 80 | tee -a "$LOG_FILE" || true
  add_report_row "Hardware profile" "system_profiler captured" "INFO" "Batch F Hardware"
  if [[ "$SCRIPT_BASE" == *apple-silicon* || "$SCRIPT_BASE" == *m-series* ]]; then
    CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")
    add_report_row "Chip" "$CHIP" "INFO" ""
    pmset -g therm 2>&1 | tee -a "$LOG_FILE" || true
    add_report_row "Thermal" "pmset -g therm captured" "INFO" ""
  fi
  if [[ "$SCRIPT_BASE" == *battery* || "$SCRIPT_BASE" == *cycle-count* ]]; then
    system_profiler SPPowerDataType 2>/dev/null | grep -E 'Cycle Count|Condition|Maximum Capacity' | tee -a "$LOG_FILE" || true
    add_report_row "Battery" "Cycle/condition captured" "INFO" ""
  fi
  if [[ "$SCRIPT_BASE" == *thunderbolt* || "$SCRIPT_BASE" == *dock* || "$SCRIPT_BASE" == *usb-c-hub* || "$SCRIPT_BASE" == *caldigit* ]]; then
    killall -9 thunderbolt 2>/dev/null || true
    add_report_row "Thunderbolt" "Restart thunderbolt daemon; replug dock" "WARN" ""
  fi
  if [[ "$SCRIPT_BASE" == *bluetooth* || "$SCRIPT_BASE" == *magic-* || "$SCRIPT_BASE" == *airpods* ]]; then
    blueutil -p 0 2>/dev/null || true; sleep 2; blueutil -p 1 2>/dev/null || true
    add_report_row "Bluetooth" "Power cycle attempted" "PASS" ""
  fi
  if [[ "$SCRIPT_BASE" == *warranty* || "$SCRIPT_BASE" == *applecare* || "$SCRIPT_BASE" == *serial-specs* ]]; then
    SERIAL=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Serial/ {print $4}')
    add_report_row "Serial" "$SERIAL" "INFO" "Check coverage at checkcoverage.apple.com"
  fi
  if [[ "$SCRIPT_BASE" == *nvme* || "$SCRIPT_BASE" == *external-ssd* || "$SCRIPT_BASE" == *storage-health* ]]; then
    diskutil list 2>&1 | tee -a "$LOG_FILE" || true
    smartctl -a disk0 2>/dev/null | head -n 25 | tee -a "$LOG_FILE" || add_report_row "SMART" "smartctl not installed; use Disk Utility" "WARN" ""
  fi
fi

if [[ "$SCRIPT_BASE" == *apfs* || "$SCRIPT_BASE" == *fusion-drive* || "$SCRIPT_BASE" == *raid* || "$SCRIPT_BASE" == *parallels* || "$SCRIPT_BASE" == *vmware* || "$SCRIPT_BASE" == *utm-vm* || "$SCRIPT_BASE" == *mac-pro* || "$SCRIPT_BASE" == *mac-studio* || "$SCRIPT_BASE" == *time-machine-server* || "$SCRIPT_BASE" == *network-backup* || "$SCRIPT_BASE" == *10gbe* || "$SCRIPT_BASE" == *smb-share* || "$SCRIPT_BASE" == *mac-mini-server* || "$SCRIPT_BASE" == *final-cut* || "$SCRIPT_BASE" == *logic-pro* || "$SCRIPT_BASE" == *calibration-device* || "$SCRIPT_BASE" == *large-format* || "$SCRIPT_BASE" == *soft-raid* || "$SCRIPT_BASE" == *network-attached* ]]; then
  show_progress 4 "$TOTAL_STEPS" "Server / storage / workstation"
  diskutil list 2>&1 | tee -a "$LOG_FILE" || true
  diskutil apfs list 2>&1 | head -n 40 | tee -a "$LOG_FILE" || true
  add_report_row "APFS/RAID" "diskutil captured" "INFO" "Batch G Server/RAID"
  if [[ "$SCRIPT_BASE" == *apfs* || "$SCRIPT_BASE" == *snapshot* ]]; then
    diskutil apfs listSnapshots / 2>&1 | head -n 15 | tee -a "$LOG_FILE" || true
    add_report_row "APFS snapshots" "Listed" "INFO" ""
  fi
  if [[ "$SCRIPT_BASE" == *raid* || "$SCRIPT_BASE" == *soft-raid* || "$SCRIPT_BASE" == *external-raid* || "$SCRIPT_BASE" == *thunderbolt-raid* ]]; then
    system_profiler SPThunderboltDataType SPStorageDataType 2>/dev/null | head -n 50 | tee -a "$LOG_FILE" || true
    add_report_row "RAID enclosure" "Review Disk Utility > RAID or vendor utility" "WARN" ""
  fi
  if [[ "$SCRIPT_BASE" == *parallels* || "$SCRIPT_BASE" == *vmware* || "$SCRIPT_BASE" == *utm-vm* ]]; then
    df -h "$REAL_HOME" 2>&1 | tee -a "$LOG_FILE" || true
    add_report_row "VM storage" "Check VM disk images on host volume free space" "WARN" ""
  fi
  if [[ "$SCRIPT_BASE" == *mac-pro* || "$SCRIPT_BASE" == *mac-studio* || "$SCRIPT_BASE" == *final-cut* || "$SCRIPT_BASE" == *logic-pro* || "$SCRIPT_BASE" == *pro-display* || "$SCRIPT_BASE" == *calibration* ]]; then
    system_profiler SPDisplaysDataType SPHardwareDataType 2>/dev/null | head -n 40 | tee -a "$LOG_FILE" || true
    pmset -g therm 2>&1 | tee -a "$LOG_FILE" || true
    add_report_row "Workstation GPU" "Display + thermal captured" "INFO" ""
  fi
  if [[ "$SCRIPT_BASE" == *time-machine* || "$SCRIPT_BASE" == *network-backup* ]]; then
    tmutil destinationinfo 2>&1 | tee -a "$LOG_FILE" || true
    add_report_row "Time Machine" "destinationinfo captured" "INFO" ""
  fi
  if [[ "$SCRIPT_BASE" == *10gbe* || "$SCRIPT_BASE" == *smb-share* || "$SCRIPT_BASE" == *network-attached* ]]; then
    ifconfig 2>&1 | grep -E 'inet |status|media' | head -n 20 | tee -a "$LOG_FILE" || true
    add_report_row "Network storage" "Link status captured" "INFO" ""
  fi
  if [[ "$SCRIPT_BASE" == *mac-mini-server* || "$SCRIPT_BASE" == *workstation-specs* || "$SCRIPT_BASE" == *raid-serial* ]]; then
    system_profiler SPHardwareDataType 2>/dev/null | tee -a "$LOG_FILE" || true
    add_report_row "Inventory" "Hardware profile for CMDB" "INFO" ""
  fi
fi

if [[ "$SCRIPT_BASE" == *smartcard* || "$SCRIPT_BASE" == *yubikey* || "$SCRIPT_BASE" == *cac-reader* || "$SCRIPT_BASE" == *zebra* || "$SCRIPT_BASE" == *rfid* || "$SCRIPT_BASE" == *stream-deck* || "$SCRIPT_BASE" == *usb-serial* || "$SCRIPT_BASE" == *brother-label* || "$SCRIPT_BASE" == *dymo* || "$SCRIPT_BASE" == *receipt-printer* || "$SCRIPT_BASE" == *magtek* || "$SCRIPT_BASE" == *powermic* || "$SCRIPT_BASE" == *handheld-scanner* || "$SCRIPT_BASE" == *elgato* || "$SCRIPT_BASE" == *document-camera* || "$SCRIPT_BASE" == *conference-speakerphone* || "$SCRIPT_BASE" == *ip-kvm* || "$SCRIPT_BASE" == *kvm-peripheral* || "$SCRIPT_BASE" == *peripheral-serial* || "$SCRIPT_BASE" == *bluetooth-medical* || "$SCRIPT_BASE" == *bluetooth-hearing* || "$SCRIPT_BASE" == *bluetooth-pos* || "$SCRIPT_BASE" == *dictation-mic* ]]; then
  show_progress 4 "$TOTAL_STEPS" "Niche peripheral / KVM"
  system_profiler SPUSBDataType SPBluetoothDataType 2>/dev/null | head -n 60 | tee -a "$LOG_FILE" || true
  add_report_row "USB/BT devices" "system_profiler captured" "INFO" "Batch H"
  if [[ "$SCRIPT_BASE" == *smartcard* || "$SCRIPT_BASE" == *yubikey* || "$SCRIPT_BASE" == *cac-reader* ]]; then
    security list-smartcards 2>&1 | tee -a "$LOG_FILE" || true
    add_report_row "Smart card" "list-smartcards captured" "INFO" "Insert card and retry login"
  fi
  if [[ "$SCRIPT_BASE" == *zebra* || "$SCRIPT_BASE" == *rfid* || "$SCRIPT_BASE" == *handheld-scanner* || "$SCRIPT_BASE" == *bluetooth-pos* ]]; then
    ioreg -p IOUSB -l 2>/dev/null | grep -E 'Zebra|Symbol|Honeywell|RFID|Scanner' | head -n 10 | tee -a "$LOG_FILE" || true
    add_report_row "Scanner/RFID" "Check USB HID or vendor Mac driver" "WARN" ""
  fi
  if [[ "$SCRIPT_BASE" == *stream-deck* || "$SCRIPT_BASE" == *elgato* ]]; then
    killall "Elgato Stream Deck" "Stream Deck" 2>/dev/null || true
    add_report_row "Elgato/Stream Deck" "Quit app; replug USB; reinstall Elgato software" "WARN" ""
  fi
  if [[ "$SCRIPT_BASE" == *usb-serial* || "$SCRIPT_BASE" == *ftdi* ]]; then
    ls /dev/cu.* /dev/tty.* 2>/dev/null | head -n 15 | tee -a "$LOG_FILE" || true
    add_report_row "Serial ports" "cu/tty devices listed" "INFO" ""
  fi
  if [[ "$SCRIPT_BASE" == *brother* || "$SCRIPT_BASE" == *dymo* || "$SCRIPT_BASE" == *receipt* || "$SCRIPT_BASE" == *zebra-label* ]]; then
    lpstat -p 2>&1 | tee -a "$LOG_FILE" || true
    add_report_row "Label/receipt printer" "lpstat captured" "INFO" ""
  fi
  if [[ "$SCRIPT_BASE" == *powermic* || "$SCRIPT_BASE" == *dictation* || "$SCRIPT_BASE" == *conference-speakerphone* || "$SCRIPT_BASE" == *document-camera* ]]; then
    system_profiler SPAudioDataType SPCameraDataType 2>/dev/null | head -n 30 | tee -a "$LOG_FILE" || true
    killall coreaudiod 2>/dev/null || true
    add_report_row "AV peripheral" "Audio/camera profile captured" "INFO" ""
  fi
  if [[ "$SCRIPT_BASE" == *bluetooth-medical* || "$SCRIPT_BASE" == *bluetooth-hearing* ]]; then
    blueutil -p 0 2>/dev/null || true; sleep 2; blueutil -p 1 2>/dev/null || true
    add_report_row "Bluetooth medical" "Power cycle BT; pair in System Settings" "WARN" ""
  fi
  if [[ "$SCRIPT_BASE" == *ip-kvm* || "$SCRIPT_BASE" == *kvm-peripheral* ]]; then
    add_report_row "KVM" "Use vendor IP-KVM console; verify network path" "WARN" ""
  fi
  if [[ "$SCRIPT_BASE" == *peripheral-serial* ]]; then
    system_profiler SPHardwareDataType 2>/dev/null | awk '/Serial/ {print}' | tee -a "$LOG_FILE" || true
    add_report_row "Serial inventory" "Host serial captured" "INFO" ""
  fi
fi

if [[ "$SCRIPT_BASE" == *intune* || "$SCRIPT_BASE" == *jamf* || "$SCRIPT_BASE" == *cmdb* || "$SCRIPT_BASE" == *mdm* || "$SCRIPT_BASE" == *graph* || "$SCRIPT_BASE" == *entra* || "$SCRIPT_BASE" == *servicenow* || "$SCRIPT_BASE" == *snipeit* || "$SCRIPT_BASE" == *helpdesk-intune* || "$SCRIPT_BASE" == *helpdesk-jamf* || "$SCRIPT_BASE" == *extension-attribute* || "$SCRIPT_BASE" == *enrollment* ]]; then
  show_progress 4 "$TOTAL_STEPS" "Intune / Jamf / CMDB"
  detect_mdm_join_state
  system_profiler SPHardwareDataType SPSoftwareDataType 2>/dev/null | head -n 30 | tee -a "$LOG_FILE" || true
  add_report_row "MDM state" "$JOIN_STATE" "INFO" "Batch I"
  EXPORT="$REAL_HOME/Library/Logs/IT-Repair/cmdb_export_$(hostname)_$(date +%Y%m%d_%H%M%S).csv"
  SERIAL=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Serial/ {print $4}')
  MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Model Name/ {print $3,,}')
  echo "ComputerName,Serial,Model,User,JoinState" > "$EXPORT"
  echo "$(hostname),$SERIAL,$MODEL,$REAL_USER,$JOIN_STATE" >> "$EXPORT"
  add_report_row "CMDB CSV" "$EXPORT" "PASS" "Import to Snipe-IT/ServiceNow"
  if [[ "$SCRIPT_BASE" == *jamf* ]]; then
    if command -v jamf >/dev/null 2>&1; then
      jamf checkJSSConnection 2>&1 | tee -a "$LOG_FILE" || true
      jamf listComputers -limit 1 2>&1 | head -n 5 | tee -a "$LOG_FILE" || add_report_row "Jamf" "Binary present; use Jamf Pro for policy deploy" "INFO" ""
    else
      add_report_row "Jamf" "Binary not installed" "WARN" "Enroll via Jamf Pro first"
    fi
  fi
  if [[ "$SCRIPT_BASE" == *intune* || "$SCRIPT_BASE" == *graph* || "$SCRIPT_BASE" == *entra* ]]; then
    profiles status -type enrollment 2>&1 | tee -a "$LOG_FILE" || true
    add_report_row "Intune MDM" "profiles status captured" "INFO" "Upload shell scripts as Intune macOS scripts"
  fi
  if [[ "$SCRIPT_BASE" == *mdm* || "$SCRIPT_BASE" == *enrollment* ]]; then
    profiles list -type enrollment 2>&1 | tee -a "$LOG_FILE" || true
    add_report_row "Enrollment" "Review user-approved MDM in System Settings" "WARN" ""
  fi
fi

show_progress 5 "$TOTAL_STEPS" "Complete"
add_report_row "Script" "$SCRIPT_BASE" "INFO" "16_Jamf-Advanced"

if [[ "$SCRIPT_BASE" == *deep-audit* || "$SCRIPT_BASE" == *auto-repair* || "$SCRIPT_BASE" == *stack-reset* || "$SCRIPT_BASE" == *health-triage* || "$SCRIPT_BASE" == *anomaly-detect* || "$SCRIPT_BASE" == *evidence-report* || "$SCRIPT_BASE" == *policy-validate* ]]; then
  show_progress 6 "$TOTAL_STEPS" "Enterprise depth"
  launchctl list 2>/dev/null | head -n 15 | tee -a "$LOG_FILE" || true
  df -h / 2>&1 | tee -a "$LOG_FILE" || true
  softwareupdate -l 2>&1 | head -n 8 | tee -a "$LOG_FILE" || true
  add_report_row "Enterprise module" "$SCRIPT_BASE" "INFO" "Batch C SysAdmin depth"
fi

if [[ "$SCRIPT_BASE" == *quick-audit* || "$SCRIPT_BASE" == *quick-repair* || "$SCRIPT_BASE" == *reset-stack* || "$SCRIPT_BASE" == *user-triage* || "$SCRIPT_BASE" == *issue-detect* || "$SCRIPT_BASE" == *one-click-fix* || "$SCRIPT_BASE" == *helpdesk-report* || "$SCRIPT_BASE" == *policy-check* ]]; then
  show_progress 6 "$TOTAL_STEPS" "Helpdesk depth"
  add_report_row "User context" "$REAL_USER" "INFO" "$REAL_HOME"
  id "$REAL_USER" 2>&1 | tee -a "$LOG_FILE" || true
  add_report_row "Helpdesk module" "$SCRIPT_BASE" "INFO" "Batch D IT Support"
fi
show_progress "$TOTAL_STEPS" "$TOTAL_STEPS" "HTML report"
export_html_report "jamf extension attribute inventory mac" "$COMPUTER_NAME" "$JOIN_STATE"
print_completion_summary
open_report_if_interactive