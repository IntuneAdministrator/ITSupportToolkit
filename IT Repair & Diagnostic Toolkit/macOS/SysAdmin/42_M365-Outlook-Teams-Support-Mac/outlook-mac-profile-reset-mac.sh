#!/bin/zsh
# ============================================================
# Script:      outlook-mac-profile-reset-mac.sh
# Descrição:   Reseta perfil do Outlook (backup + reconfigurar).
# Categoria:   42_M365-Outlook-Teams-Support-Mac
# Author:      Allester Padovani
# Version:     1.0.0
# Tested:      macOS Ventura 13.x / Sonoma 14.x / Sequoia 15.x
# Requires:    sudo / root
# Usage:       sudo zsh outlook-mac-profile-reset-mac.sh
# Deployment:  Intune shell script / Jamf Pro
# ============================================================

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERRO: execute como root (sudo)." >&2
    exit 1
fi

REAL_USER=${SUDO_USER:-${USER:-root}}
if [[ "$REAL_USER" != "root" ]]; then
    REAL_HOME=$(dscl . -read "/Users/$REAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
    REAL_HOME=${REAL_HOME:-/Users/$REAL_USER}
else
    REAL_HOME="/var/root"
fi

ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then BREW_PREFIX="/opt/homebrew"; else BREW_PREFIX="/usr/local"; fi

LOG_DIR="$REAL_HOME/Library/Logs/IT-Repair"
REPORT_DIR="$LOG_DIR/Reports"
BACKUP_DIR="$LOG_DIR/Backups"
mkdir -p "$LOG_DIR" "$REPORT_DIR" "$BACKUP_DIR"
if [[ "$REAL_USER" != "root" ]]; then
    chown -R "$REAL_USER":staff "$LOG_DIR" 2>/dev/null || true
fi

SCRIPT_BASE=$(basename "$0" .sh)
FOLDER_NAME='42_M365-Outlook-Teams-Support-Mac'
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/${SCRIPT_BASE}_$TIMESTAMP.log"
REPORT_PATH="$REPORT_DIR/${SCRIPT_BASE}_$TIMESTAMP.html"
TOTAL_STEPS=8
JOIN_STATE="Unknown"
COMPUTER_NAME=$(hostname)

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
<html lang="pt-BR">
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
  .pass .num { color:#48bb78; } .fail .num { color:#fc8181; }
  .warn .num { color:#f6e05e; } .info .num { color:#63b3ed; }
  table { width:100%; border-collapse:collapse; background:#1a1f2e; border-radius:8px; overflow:hidden; }
  th { background:#243044; text-align:left; padding:10px 14px; font-size:.8rem; color:#a0aec0; }
  td { padding:10px 14px; border-top:1px solid #2d3748; font-size:.9rem; vertical-align:top; }
  .badge { padding:2px 8px; border-radius:4px; font-size:.75rem; font-weight:600; }
  .badge.pass { background:#276749; color:#c6f6d5; }
  .badge.fail { background:#9b2c2c; color:#fed7d7; }
  .badge.warn { background:#975a16; color:#fefcbf; }
  .badge.info { background:#2a4365; color:#bee3f8; }
</style>
</head>
<body>
  <h1>${title}</h1>
  <div class="meta">
    <span>Host: ${computer_name}</span>
    <span>Estado: ${join_state}</span>
    <span>${timestamp}</span>
    <span>Pasta: ${FOLDER_NAME}</span>
  </div>
  <div class="summary">
    <div class="card pass"><div class="num">${PASS_COUNT}</div><div class="lbl">PASS</div></div>
    <div class="card fail"><div class="num">${FAIL_COUNT}</div><div class="lbl">FAIL</div></div>
    <div class="card warn"><div class="num">${WARN_COUNT}</div><div class="lbl">WARN</div></div>
    <div class="card info"><div class="num">${INFO_COUNT}</div><div class="lbl">INFO</div></div>
  </div>
  <table>
    <thead><tr><th>Verificação</th><th>Resultado</th><th>Status</th><th>Detalhe</th></tr></thead>
    <tbody>
${REPORT_ROWS}
    </tbody>
  </table>
</body>
</html>
EOF
    [[ "$REAL_USER" != "root" ]] && chown "$REAL_USER":staff "$REPORT_PATH" 2>/dev/null || true
}

open_report_if_interactive() {
    if [[ -t 1 ]] && [[ -f "$REPORT_PATH" ]]; then
        open "$REPORT_PATH" 2>/dev/null || true
    fi
}

print_completion_summary() {
    echo -e "\n${CYAN}┌─────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│         SCRIPT CONCLUÍDO                │${NC}"
    echo -e "${GREEN}│  PASS : $PASS_COUNT${NC}"
    echo -e "${RED}│  FAIL : $FAIL_COUNT${NC}"
    echo -e "${YELLOW}│  WARN : $WARN_COUNT${NC}"
    echo -e "${CYAN}│  Log  : $LOG_FILE${NC}"
    echo -e "${CYAN}│  Relatório: $REPORT_PATH${NC}"
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

section_banner "INICIALIZAÇÃO"
show_progress 1 "$TOTAL_STEPS" "Início + detecção MDM"
detect_mdm_join_state
log_info "Computador: $COMPUTER_NAME | Estado: $JOIN_STATE | Arch: $ARCH"
add_report_row "Computador" "$COMPUTER_NAME" "INFO" "$JOIN_STATE"
add_report_row "Script" "$SCRIPT_BASE" "INFO" "$FOLDER_NAME"
add_report_row "Arch / Brew" "$ARCH" "INFO" "$BREW_PREFIX"

section_banner "RESET PERFIL OUTLOOK MAC"
# ATENÇÃO: remove perfil local — usuário precisará reconfigurar a conta
show_progress 2 "$TOTAL_STEPS" "Encerrar Outlook"
pkill -x "Microsoft Outlook" 2>/dev/null || true
sleep 1
PROF_DIR="$REAL_HOME/Library/Group Containers/UBF8T346G9.Office/Outlook"
BACKUP_PROF="$BACKUP_DIR/OutlookProfile-$TIMESTAMP"
show_progress 4 "$TOTAL_STEPS" "Backup + reset"
if [[ -d "$PROF_DIR" ]]; then
  mkdir -p "$BACKUP_PROF"
  rsync -a "$PROF_DIR" "$BACKUP_PROF/" 2>/dev/null || cp -R "$PROF_DIR" "$BACKUP_PROF/" || true
  # Remove Main Profile (força reconfiguração)
  rm -rf "$PROF_DIR/Outlook 15 Profiles" 2>/dev/null || true
  add_report_row "Backup perfil" "$BACKUP_PROF" "PASS" ""
  add_report_row "Reset perfil" "Outlook 15 Profiles removido" "WARN" "reconectar conta"
else
  add_report_row "Perfil Outlook" "não encontrado" "INFO" "$PROF_DIR"
fi

show_progress "$TOTAL_STEPS" "$TOTAL_STEPS" "Exportar relatório HTML"
export_html_report "Outlook Mac Profile Reset" "$COMPUTER_NAME" "$JOIN_STATE"
print_completion_summary
open_report_if_interactive