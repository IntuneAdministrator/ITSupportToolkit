#!/bin/zsh
# Author: Allester Padovani
# ============================================================
# Script: ca-block-signin-explain-mac.sh | ITSupport/31_M365-Access-SignIn-HD-Mac | v1.4.0 Phase12 M365 cloud
# Usage: zsh ca-block-signin-explain-mac.sh [user@domain.com]
# Optional: GRAPH_TOKEN=... for curl Graph calls; pwsh + Microsoft.Graph preferred
# Root NOT required (tenant admin roles matter, not local sudo)
# ============================================================
set -euo pipefail
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=${HOME}
if [[ -n "${SUDO_USER:-}" ]]; then
  REAL_HOME=$(dscl . -read "/Users/$REAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
  REAL_HOME=${REAL_HOME:-/Users/$REAL_USER}
fi
ARCH=$(uname -m); [[ "$ARCH" == "arm64" ]] && BREW_PREFIX="/opt/homebrew" || BREW_PREFIX="/usr/local"
LOG_DIR="$REAL_HOME/Library/Logs/IT-Repair"; REPORT_DIR="$LOG_DIR/Reports"; BACKUP_DIR="$LOG_DIR/Backups"
mkdir -p "$LOG_DIR" "$REPORT_DIR" "$BACKUP_DIR"
SCRIPT_BASE=$(basename "$0" .sh); FOLDER_NAME='31_M365-Access-SignIn-HD-Mac'; TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/${SCRIPT_BASE}_$TIMESTAMP.log"; REPORT_PATH="$REPORT_DIR/${SCRIPT_BASE}_$TIMESTAMP.html"
TOTAL_STEPS=8; JOIN_STATE="Unknown"; COMPUTER_NAME=$(hostname)
TARGET_UPN=${1:-${ITREPAIR_UPN:-}}
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
add_report_row "Module" "31_M365-Access-SignIn-HD-Mac" "INFO" "ITSupport Phase12 M365"
add_report_row "M365 Admin" "https://admin.microsoft.com" "INFO" ""
add_report_row "Entra Admin" "https://entra.microsoft.com" "INFO" ""
add_report_row "Exchange Admin" "https://admin.exchange.microsoft.com" "INFO" ""
add_report_row "Teams Admin" "https://admin.teams.microsoft.com" "INFO" ""
add_report_row "Intune Admin" "https://intune.microsoft.com" "INFO" ""
add_report_row "Service Health" "https://admin.microsoft.com/#/servicehealth" "INFO" ""
if [[ -n "${TARGET_UPN:-}" ]]; then add_report_row "Target UPN" "$TARGET_UPN" "INFO" ""; else add_report_row "Target UPN" "Not set" "WARN" "Pass UPN as arg 1 or ITREPAIR_UPN"; fi
show_progress 2 "$TOTAL_STEPS" "Tooling"
if command -v pwsh >/dev/null 2>&1; then
  add_report_row "pwsh" "Found" "PASS" "Prefer Microsoft.Graph on PowerShell 7"
else
  add_report_row "pwsh" "Missing" "INFO" "brew install --cask powershell - or use GRAPH_TOKEN + curl"
fi
if [[ -n "${GRAPH_TOKEN:-}" ]]; then add_report_row "GRAPH_TOKEN" "Set" "PASS" "Will use Graph REST"; else add_report_row "GRAPH_TOKEN" "Unset" "INFO" "Export GRAPH_TOKEN from device-code/app flow for REST"; fi
section_banner "GRAPH TENANT ADMIN MAC"
show_progress 3 "$TOTAL_STEPS" "Graph"
graph_get() {
  local path="$1"
  if [[ -z "${GRAPH_TOKEN:-}" ]]; then echo "NO_TOKEN"; return 1; fi
  curl -fsS -H "Authorization: Bearer $GRAPH_TOKEN" -H "Content-Type: application/json" "https://graph.microsoft.com/v1.0$path" 2>/dev/null || return 1
}
if [[ "$SCRIPT_BASE" == *connect-devicecode* ]]; then
  add_report_row "Connect tip" "pwsh -c Connect-MgGraph -UseDeviceCode" "INFO" "Or Azure CLI / device code for token"
fi
if [[ -n "${TARGET_UPN:-}" && -n "${GRAPH_TOKEN:-}" ]]; then
  ENC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$TARGET_UPN" 2>/dev/null || echo "$TARGET_UPN")
  RESP=$(graph_get "/users/$ENC?\$select=displayName,accountEnabled,userPrincipalName" || true)
  if [[ -n "${RESP:-}" && "$RESP" != "NO_TOKEN" ]]; then
    echo "$RESP" | tee -a "$LOG_FILE"
    add_report_row "Graph user" "Fetched" "PASS" "$TARGET_UPN"
  else
    add_report_row "Graph user" "Token/query failed" "WARN" "Set GRAPH_TOKEN"
  fi
fi
if [[ "$SCRIPT_BASE" == *license-sku* && -n "${GRAPH_TOKEN:-}" ]]; then
  graph_get "/subscribedSkus" | tee -a "$LOG_FILE" || true
  add_report_row "subscribedSkus" "Queried" "INFO" ""
fi
if [[ "$SCRIPT_BASE" == *service-health* && -n "${GRAPH_TOKEN:-}" ]]; then
  graph_get "/admin/serviceAnnouncement/healthOverviews" | tee -a "$LOG_FILE" || true
  add_report_row "Service health" "API attempted" "INFO" ""
fi
if command -v pwsh >/dev/null 2>&1 && [[ "$SCRIPT_BASE" == *user-lookup* || "$SCRIPT_BASE" == *group-membership* || "$SCRIPT_BASE" == *conditional-access* ]]; then
  add_report_row "pwsh path" "Use Microsoft.Graph cmdlets on Mac via pwsh" "INFO" "Install-Module Microsoft.Graph -Scope CurrentUser"
fi
show_progress 5 "$TOTAL_STEPS" "Graph Mac done" section_banner "M365 HELPDESK CLOUD MAC"
show_progress 3 "$TOTAL_STEPS" "HD cloud"
if [[ -z "${TARGET_UPN:-}" ]]; then
  add_report_row "UPN required" "Pass user@domain as \$1" "WARN" ""
fi
case "$SCRIPT_BASE" in
  *license*|*mfa*|*password*|*guest*|*blocked*)
    add_report_row "Entra HD" "https://entra.microsoft.com" "INFO" "Licenses, auth methods, block sign-in"
    ;;
  *mailbox*|*calendar*|*forwarding*|*recoverable*|*shared*)
    add_report_row "EAC HD" "https://admin.exchange.microsoft.com" "INFO" "Quota, shared, forwarding"
    ;;
  *teams*|*onedrive*|*sharepoint*|*odsp*)
    add_report_row "Collab HD" "Teams Admin + SPO Admin + client reset scripts" "INFO" ""
    ;;
  *ca-block*|*legacy*|*session*|*service-health*|*pim*)
    add_report_row "Access HD" "Sign-in logs + CA + Service Health + PIM" "INFO" ""
    add_report_row "Service Health" "https://admin.microsoft.com/#/servicehealth" "INFO" ""
    ;;
esac
if [[ -n "${GRAPH_TOKEN:-}" && -n "${TARGET_UPN:-}" && "$SCRIPT_BASE" == *license* ]]; then
  ENC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$TARGET_UPN" 2>/dev/null || echo "$TARGET_UPN")
  curl -fsS -H "Authorization: Bearer $GRAPH_TOKEN" "https://graph.microsoft.com/v1.0/users/$ENC?\$select=displayName,assignedLicenses,accountEnabled" | tee -a "$LOG_FILE" || true
  add_report_row "License REST" "Attempted" "INFO" ""
fi
# Local Office token/cache hint (client half of M365 HD)
if [[ "$SCRIPT_BASE" == *legacy* || "$SCRIPT_BASE" == *session* ]]; then
  killall "Microsoft Outlook" "Microsoft Teams" "OneDrive" 2>/dev/null || true
  add_report_row "Local clients" "Quit for re-auth" "PASS" "After cloud session revoke"
fi
show_progress 5 "$TOTAL_STEPS" "HD Mac done"
show_progress "$TOTAL_STEPS" "$TOTAL_STEPS" "Report"
export_html_report "ca block signin explain mac" "$COMPUTER_NAME" "$JOIN_STATE"
print_completion_summary
open_report_if_interactive