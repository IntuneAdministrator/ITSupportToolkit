#!/bin/zsh
# ============================================================
# Script:      create-local-user-default-profile-mac.sh
# Descrição:   Cria usuário local com perfil padrão (idempotente).
# Categoria:   38_User-Onboarding-Offboarding-Mac
# Author:      Allester Padovani
# Version:     1.1.0
# Requires:    macOS 12+ (Monterey); sudo/root para mutações
# Tested:      macOS Ventura 13 / Sonoma 14 / Sequoia 15
# Exit codes:  0 = sucesso; 1 = falha (Intune/Jamf)
# Idempotent:  Sim — se usuário já existe, só reporta PASS e sai.
# Rollback:    Se criação parcial falhar, remove usuário incompleto criado neste run.
# Usage:       sudo NEW_USER=jdoe FULL_NAME="Jane Doe" zsh create-local-user-default-profile-mac.sh
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

NEW_USER=${NEW_USER:-}
FULL_NAME=${FULL_NAME:-$NEW_USER}
CREATED_NOW=0
mkdir -p "$ROLLBACK_DIR"
log_info "Início create-local-user"
if [[ -z "$NEW_USER" ]]; then log_error "Defina NEW_USER"; add_report_row "NEW_USER" "missing" "FAIL" ""; export_html_report "Create Local User"; exit 1; fi
validate_username "$NEW_USER" || { add_report_row "validate" "$NEW_USER" "FAIL" ""; export_html_report "Create Local User"; exit 1; }
if id "$NEW_USER" &>/dev/null; then
  log_success "Usuário já existe — idempotente, nada a fazer"
  add_report_row "Usuário" "$NEW_USER" "PASS" "já existia"
  export_html_report "Create Local User"
  exit 0
fi
prompt_secret USER_PASSWORD "Senha para $NEW_USER" || { add_report_row "password" "missing" "FAIL" ""; export_html_report "Create Local User"; exit 1; }
echo "NEW_USER=$NEW_USER" > "$ROLLBACK_DIR/intent.txt"
if sysadminctl -addUser "$NEW_USER" -fullName "$FULL_NAME" -password "$USER_PASSWORD" -home "/Users/$NEW_USER" 2>&1 | tee -a "$LOG_FILE"; then
  CREATED_NOW=1
else
  if ! id "$NEW_USER" &>/dev/null; then
    MAXID=$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)
    NEWID=$((MAXID+1))
    dscl . -create "/Users/$NEW_USER" || true
    dscl . -create "/Users/$NEW_USER" UserShell /bin/zsh
    dscl . -create "/Users/$NEW_USER" RealName "$FULL_NAME"
    dscl . -create "/Users/$NEW_USER" UniqueID "$NEWID"
    dscl . -create "/Users/$NEW_USER" PrimaryGroupID 20
    dscl . -create "/Users/$NEW_USER" NFSHomeDirectory "/Users/$NEW_USER"
    if dscl . -passwd "/Users/$NEW_USER" "$USER_PASSWORD" 2>&1 | tee -a "$LOG_FILE"; then
      createhomedir -c -u "$NEW_USER" 2>&1 | tee -a "$LOG_FILE" || true
      CREATED_NOW=1
      add_report_row "dscl" "created" "PASS" "UID $NEWID"
    else
      dscl . -delete "/Users/$NEW_USER" 2>/dev/null || true
      add_report_row "create" "rolled back" "FAIL" "senha"
      unset USER_PASSWORD
      export_html_report "Create Local User"; exit 1
    fi
  fi
fi
HOME_DIR=$(dscl . -read "/Users/$NEW_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
if [[ -z "$HOME_DIR" || "$HOME_DIR" == "/" || "$HOME_DIR" != /Users/* ]]; then
  if [[ $CREATED_NOW -eq 1 ]]; then
    sysadminctl -deleteUser "$NEW_USER" 2>/dev/null || dscl . -delete "/Users/$NEW_USER" 2>/dev/null || true
  fi
  add_report_row "HOME_DIR" "${HOME_DIR:-empty}" "FAIL" "rollback"
  unset USER_PASSWORD
  export_html_report "Create Local User"; exit 1
fi
mkdir -p "$HOME_DIR/Desktop" "$HOME_DIR/Documents" "$HOME_DIR/Downloads"
chown -R "$NEW_USER":staff "$HOME_DIR" 2>/dev/null || true
add_report_row "perfil" "$HOME_DIR" "PASS" "pastas padrão"
unset USER_PASSWORD
export_html_report "Create Local User"