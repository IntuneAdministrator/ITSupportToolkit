#!/bin/zsh
# ============================================================
# Script:      transfer-user-files-before-remove-mac.sh
# Descrição:   Copia arquivos para /Users/Shared (confinado).
# Categoria:   38_User-Onboarding-Offboarding-Mac
# Author:      Allester Padovani
# Version:     1.1.0
# Requires:    macOS 12+ (Monterey); sudo/root para mutações
# Tested:      macOS Ventura 13 / Sonoma 14 / Sequoia 15
# Exit codes:  0 = sucesso; 1 = falha (Intune/Jamf)
# Idempotent:  Sim — rsync reexecutável.
# Rollback:    Origem intacta; DEST sob /Users/Shared.
# Usage:       sudo SOURCE_USER=jdoe zsh transfer-user-files-before-remove-mac.sh
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
LOG_DIR="$REAL_HOME/Library/Logs/IT-Repair"
REPORT_DIR="$LOG_DIR/Reports"; BACKUP_DIR="$LOG_DIR/Backups"
mkdir -p "$LOG_DIR" "$REPORT_DIR" "$BACKUP_DIR"
[[ "$REAL_USER" != "root" ]] && chown -R "$REAL_USER":staff "$LOG_DIR" 2>/dev/null || true
SCRIPT_BASE=$(basename "$0" .sh)
FOLDER_NAME='38_User-Onboarding-Offboarding-Mac'
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/${SCRIPT_BASE}_$TIMESTAMP.log"
REPORT_PATH="$REPORT_DIR/${SCRIPT_BASE}_$TIMESTAMP.html"
ROLLBACK_DIR="$BACKUP_DIR/rollback-${SCRIPT_BASE}-$TIMESTAMP"
PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0; INFO_COUNT=0; REPORT_ROWS=""
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info(){ echo -e "${CYAN}[INFO] $(date '+%H:%M:%S') $1${NC}" | tee -a "$LOG_FILE"; }
log_success(){ echo -e "${GREEN}[OK] $(date '+%H:%M:%S') $1${NC}" | tee -a "$LOG_FILE"; }
log_warn(){ echo -e "${YELLOW}[WARN] $(date '+%H:%M:%S') $1${NC}" | tee -a "$LOG_FILE"; }
log_error(){ echo -e "${RED}[ERROR] $(date '+%H:%M:%S') $1${NC}" | tee -a "$LOG_FILE"; }
add_report_row(){ local c="$1" r="$2" s="$3" d="${4:-}"; case "$s" in PASS) PASS_COUNT=$((PASS_COUNT+1));; FAIL) FAIL_COUNT=$((FAIL_COUNT+1));; WARN) WARN_COUNT=$((WARN_COUNT+1));; INFO) INFO_COUNT=$((INFO_COUNT+1));; esac; REPORT_ROWS+="<tr><td>$c</td><td>$r</td><td>$s</td><td>$d</td></tr>"; }
export_html_report(){ cat > "$REPORT_PATH" <<EOF
<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8"><title>$1</title></head>
<body style="font-family:sans-serif;background:#0f1117;color:#e2e8f0;padding:24px"><h1>$1</h1>
<p>Host: $(hostname) | $TIMESTAMP | FAIL=$FAIL_COUNT WARN=$WARN_COUNT</p>
<table border="1" cellpadding="6"><tr><th>Check</th><th>Result</th><th>Status</th><th>Detail</th></tr>
$REPORT_ROWS</table>
<p>Rollback dir: $ROLLBACK_DIR</p></body></html>
EOF
  [[ "$REAL_USER" != "root" ]] && chown "$REAL_USER":staff "$REPORT_PATH" 2>/dev/null || true
}
get_exit_code(){ if [[ $FAIL_COUNT -gt 0 ]]; then echo 1; else echo 0; fi; }
trap 'ec=$(get_exit_code); exit $ec' EXIT
validate_username(){
  local u="$1"
  [[ "$u" =~ ^[a-z_][a-z0-9_-]*$ ]] || { log_error "USERNAME inválido: $u"; return 1; }
  case "$u" in root|daemon|nobody|admin|Guest|_*) log_error "USERNAME reservado: $u"; return 1;; esac
  return 0
}
prompt_secret(){
  local var="$1" prompt="$2"
  if [[ -n "${(P)var:-}" ]]; then
    log_warn "Secret veio do ambiente — evite USER_PASSWORD/CERT_PASSWORD em env/argv em produção."
    return 0
  fi
  if [[ -t 0 ]]; then
    echo -n "$prompt: "
    read -rs val
    echo
    typeset -g "$var=$val"
  else
    log_error "Secret obrigatório não fornecido (sem TTY). Use prompt interativo."
    return 1
  fi
}
SOURCE_USER=${SOURCE_USER:-}; DEST_DIR=${DEST_DIR:-}; mkdir -p "$ROLLBACK_DIR"
if [[ -z "$SOURCE_USER" ]] || ! id "$SOURCE_USER" &>/dev/null; then add_report_row "SOURCE_USER" "invalid" "FAIL" ""; export_html_report "Transfer"; exit 1; fi
SRC_HOME=$(dscl . -read "/Users/$SOURCE_USER" NFSHomeDirectory | awk '{print $2}')
if [[ -z "$SRC_HOME" || "$SRC_HOME" != /Users/* ]]; then add_report_row "SRC_HOME" "unsafe" "FAIL" "$SRC_HOME"; export_html_report "Transfer"; exit 1; fi
DEST_DIR=${DEST_DIR:-"/Users/Shared/Offboard-$SOURCE_USER-$TIMESTAMP"}
case "$DEST_DIR" in /Users/Shared/*) ;; *) add_report_row "DEST_DIR" "rejected" "FAIL" "$DEST_DIR"; export_html_report "Transfer"; exit 1;; esac
mkdir -p "$DEST_DIR"; echo "$DEST_DIR" > "$ROLLBACK_DIR/dest.txt"
for d in Desktop Documents Downloads; do
  if [[ -d "$SRC_HOME/$d" ]]; then
    rsync -a "$SRC_HOME/$d" "$DEST_DIR/" 2>&1 | tee -a "$LOG_FILE" || cp -R "$SRC_HOME/$d" "$DEST_DIR/" || { add_report_row "copy $d" "fail" "FAIL" ""; export_html_report "Transfer"; exit 1; }
    add_report_row "copy $d" "ok" "PASS" ""
  else add_report_row "copy $d" "absent" "INFO" ""; fi
done
chmod -R 750 "$DEST_DIR" 2>/dev/null || true
add_report_row "DEST" "$DEST_DIR" "PASS" ""
export_html_report "Transfer User Files"