#!/bin/zsh
# Author: Allester Padovani
# ============================================================
# Script: login-items-slow-boot-mac.sh | Phase 13 common problems | ITSupport/04_Slow-Mac-Fix
# Requires: sudo | Usage: sudo zsh login-items-slow-boot-mac.sh
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
SCRIPT_BASE=$(basename "$0" .sh); FOLDER_NAME='04_Slow-Mac-Fix'
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
add_report_row "Module" "04_Slow-Mac-Fix" "INFO" "ITSupport"
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

show_progress 5 "$TOTAL_STEPS" "Complete"
add_report_row "Script" "$SCRIPT_BASE" "INFO" "04_Slow-Mac-Fix"
show_progress "$TOTAL_STEPS" "$TOTAL_STEPS" "HTML report"
export_html_report "login items slow boot mac" "$COMPUTER_NAME" "$JOIN_STATE"
print_completion_summary
open_report_if_interactive