#!/bin/zsh
# Author: Allester Padovani
# ============================================================
# Script: trash-corrupt-empty-mac.sh | ITSupport/25_Finder-Spotlight-Helpdesk | v1.3.0 Phase11
# Requires: sudo | Usage: sudo zsh trash-corrupt-empty-mac.sh
# ============================================================
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "ERROR: sudo required" >&2; exit 1; }
REAL_USER=${SUDO_USER:-root}
if [[ "$REAL_USER" != "root" ]]; then
  REAL_HOME=$(dscl . -read "/Users/$REAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
  REAL_HOME=${REAL_HOME:-/Users/$REAL_USER}
else REAL_HOME="/var/root"; fi
ARCH=$(uname -m); [[ "$ARCH" == "arm64" ]] && BREW_PREFIX="/opt/homebrew" || BREW_PREFIX="/usr/local"
LOG_DIR="$REAL_HOME/Library/Logs/IT-Repair"; REPORT_DIR="$LOG_DIR/Reports"; BACKUP_DIR="$LOG_DIR/Backups"
mkdir -p "$LOG_DIR" "$REPORT_DIR" "$BACKUP_DIR"
[[ "$REAL_USER" != "root" ]] && chown -R "$REAL_USER":staff "$LOG_DIR" 2>/dev/null || true
SCRIPT_BASE=$(basename "$0" .sh); FOLDER_NAME='25_Finder-Spotlight-Helpdesk'; TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/${SCRIPT_BASE}_$TIMESTAMP.log"; REPORT_PATH="$REPORT_DIR/${SCRIPT_BASE}_$TIMESTAMP.html"
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
add_report_row "Module" "25_Finder-Spotlight-Helpdesk" "INFO" "ITSupport"
section_banner "PRINT CUPS ENTERPRISE"
show_progress 2 "$TOTAL_STEPS" "CUPS"
launchctl kickstart -k system/org.cups.cupsd 2>/dev/null || true
lpstat -p -d 2>&1 | tee -a "$LOG_FILE" || true
add_report_row "CUPS queues" "Listed" "INFO" ""
if [[ "$SCRIPT_BASE" == *error-log* || "$SCRIPT_BASE" == *deep-repair* ]]; then
  tail -n 80 /var/log/cups/error_log 2>/dev/null | tee -a "$LOG_FILE" || true
  cancel -a 2>/dev/null || true
  add_report_row "CUPS jobs" "cancel -a attempted" "PASS" ""
fi
if [[ "$SCRIPT_BASE" == *airprint* || "$SCRIPT_BASE" == *ipp* ]]; then
  dns-sd -B _ipp._tcp local. 2>&1 | head -n 20 | tee -a "$LOG_FILE" || true
  add_report_row "IPP/AirPrint browse" "Sample" "INFO" ""
fi
show_progress 5 "$TOTAL_STEPS" "Print done" section_banner "ITSUPPORT MAC PHASE11"
show_progress 2 "$TOTAL_STEPS" "Helpdesk quick"
add_report_row "User" "$REAL_USER" "INFO" "$REAL_HOME"
if [[ "$SCRIPT_BASE" == *coreaudio* || "$SCRIPT_BASE" == *mic* || "$SCRIPT_BASE" == *camera* || "$SCRIPT_BASE" == *hdmi* || "$SCRIPT_BASE" == *teams-zoom* || "$SCRIPT_BASE" == *av-* ]]; then
  killall coreaudiod 2>/dev/null || true
  killall "Microsoft Teams" "zoom.us" 2>/dev/null || true
  add_report_row "AV stack" "coreaudiod + collab apps refreshed" "PASS" ""
fi
if [[ "$SCRIPT_BASE" == *language* || "$SCRIPT_BASE" == *keyboard* || "$SCRIPT_BASE" == *region* || "$SCRIPT_BASE" == *dictation* || "$SCRIPT_BASE" == *font* ]]; then
  defaults read NSGlobalDomain AppleLanguages 2>&1 | tee -a "$LOG_FILE" || true
  defaults read NSGlobalDomain AppleLocale 2>&1 | tee -a "$LOG_FILE" || true
  add_report_row "Language/Locale" "Captured" "INFO" ""
fi
if [[ "$SCRIPT_BASE" == *login* || "$SCRIPT_BASE" == *launch-agent* || "$SCRIPT_BASE" == *loginwindow* || "$SCRIPT_BASE" == *filevault-unlock* || "$SCRIPT_BASE" == *desktop-picture* ]]; then
  osascript -e 'tell application "System Events" to get the name of every login item' 2>&1 | tee -a "$LOG_FILE" || true
  ls "$REAL_HOME/Library/LaunchAgents" 2>/dev/null | tee -a "$LOG_FILE" || true
  add_report_row "Login items / LaunchAgents" "Listed" "INFO" ""
fi
if [[ "$SCRIPT_BASE" == *finder* || "$SCRIPT_BASE" == *spotlight* || "$SCRIPT_BASE" == *trash* || "$SCRIPT_BASE" == *sidebar* || "$SCRIPT_BASE" == *desktop-stack* ]]; then
  killall Finder 2>/dev/null || true
  if [[ "$SCRIPT_BASE" == *spotlight* ]]; then
    mdutil -E / 2>&1 | tee -a "$LOG_FILE" || true
    add_report_row "Spotlight" "mdutil -E /" "PASS" "Reindex started"
  else
    add_report_row "Finder" "Relaunched" "PASS" ""
  fi
fi
if [[ "$SCRIPT_BASE" == *home-wifi* || "$SCRIPT_BASE" == *vpn* || "$SCRIPT_BASE" == *clamshell* || "$SCRIPT_BASE" == *continuity* || "$SCRIPT_BASE" == *airprint* ]]; then
  scutil --proxy 2>&1 | tee -a "$LOG_FILE" || true
  pmset -g 2>&1 | head -n 25 | tee -a "$LOG_FILE" || true
  add_report_row "Remote work" "Proxy/power sampled" "INFO" ""
fi
if [[ "$SCRIPT_BASE" == *account* || "$SCRIPT_BASE" == *keychain* || "$SCRIPT_BASE" == *secure-token* || "$SCRIPT_BASE" == *password-policy* || "$SCRIPT_BASE" == *activation-lock* ]]; then
  sysadminctl -secureTokenStatus "$REAL_USER" 2>&1 | tee -a "$LOG_FILE" || true
  fdesetup status 2>&1 | tee -a "$LOG_FILE" || true
  add_report_row "Account/FV/SecureToken" "Queried" "INFO" "Activation Lock: check Apple Business Manager"
fi
show_progress 5 "$TOTAL_STEPS" "ITSupport Mac P11 done"
show_progress "$TOTAL_STEPS" "$TOTAL_STEPS" "Report"
export_html_report "trash corrupt empty mac" "$COMPUTER_NAME" "$JOIN_STATE"
print_completion_summary
open_report_if_interactive