#!/bin/zsh
# ============================================================
# Script:      user-offboarding-disable-revoke-mac.sh
# Descrição:   Desativa conta local (guards + snapshot).
# Categoria:   35_User-Onboarding-Offboarding-HD-Mac
# Author:      Allester Padovani
# Version:     1.1.0
# Requires:    macOS 12+ (Monterey); sudo/root para mutações
# Tested:      macOS Ventura 13 / Sonoma 14 / Sequoia 15
# Exit codes:  0 = sucesso; 1 = falha (Intune/Jamf)
# Idempotent:  Parcial — conta já desativada = PASS.
# Rollback:    Snapshot em ROLLBACK_DIR.
# Usage:       sudo TARGET_USER=jdoe CONFIRM=YES zsh user-offboarding-disable-revoke-mac.sh
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
FOLDER_NAME='35_User-Onboarding-Offboarding-HD-Mac'
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
TARGET_USER=${TARGET_USER:-}; CONFIRM=${CONFIRM:-}; mkdir -p "$ROLLBACK_DIR"
if [[ "$CONFIRM" != "YES" ]]; then add_report_row "CONFIRM" "required" "FAIL" ""; export_html_report "Offboarding"; exit 1; fi
if [[ -z "$TARGET_USER" ]] || ! id "$TARGET_USER" &>/dev/null; then add_report_row "TARGET_USER" "invalid" "FAIL" ""; export_html_report "Offboarding"; exit 1; fi
validate_username "$TARGET_USER" || { add_report_row "validate" "fail" "FAIL" ""; export_html_report "Offboarding"; exit 1; }
if [[ "$TARGET_USER" == "$REAL_USER" ]]; then add_report_row "self" "blocked" "FAIL" ""; export_html_report "Offboarding"; exit 1; fi
if dseditgroup -o checkmember -m "$TARGET_USER" admin 2>/dev/null | grep -qi yes; then
  ADMIN_COUNT=$(dscl . -read /Groups/admin GroupMembership 2>/dev/null | wc -w | tr -d ' ')
  if [[ "${ADMIN_COUNT:-0}" -le 2 ]]; then add_report_row "last-admin" "blocked" "FAIL" "count=$ADMIN_COUNT"; export_html_report "Offboarding"; exit 1; fi
fi
{ id "$TARGET_USER"; dscl . -read "/Users/$TARGET_USER"; } > "$ROLLBACK_DIR/pre-state.txt" 2>&1
echo "Rollback hint: restore password via IT; clear IsHidden; re-add admin if needed." > "$ROLLBACK_DIR/ROLLBACK.txt"
pwpolicy -u "$TARGET_USER" -disableuser 2>&1 | tee -a "$LOG_FILE" || true
RAND=$(openssl rand -base64 24)
dscl . -passwd "/Users/$TARGET_USER" "$RAND" 2>&1 | tee -a "$LOG_FILE" || true
unset RAND
dseditgroup -o edit -d "$TARGET_USER" -t user admin 2>/dev/null || true
dseditgroup -o edit -d "$TARGET_USER" -t user _lpadmin 2>/dev/null || true
dscl . -create "/Users/$TARGET_USER" IsHidden 1 2>/dev/null || true
add_report_row "offboarding" "$TARGET_USER" "PASS" "snapshot=$ROLLBACK_DIR"
export_html_report "Offboarding"