#!/bin/zsh
# ============================================================
# Script:      certificate-install-cli-mac.sh
# Descrição:   Instala certificado. trustRoot só com TRUST_ROOT=YES + CONFIRM=YES.
# Categoria:   38_Certificate-Management-HD-Mac
# Author:      Allester Padovani
# Version:     1.1.0
# Requires:    macOS 12+ (Monterey); sudo/root para mutações
# Tested:      macOS Ventura 13 / Sonoma 14 / Sequoia 15
# Exit codes:  0 = sucesso; 1 = falha (Intune/Jamf)
# Idempotent:  Parcial.
# Rollback:    delete-certificate hint em ROLLBACK_DIR.
# Usage:       sudo CERT_PATH=/path/cert.cer zsh certificate-install-cli-mac.sh
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
FOLDER_NAME='38_Certificate-Management-HD-Mac'
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
CERT_PATH=${CERT_PATH:-}; KEYCHAIN=${KEYCHAIN:-/Library/Keychains/System.keychain}; TRUST_ROOT=${TRUST_ROOT:-NO}; CONFIRM=${CONFIRM:-}
mkdir -p "$ROLLBACK_DIR"
if [[ -z "$CERT_PATH" || ! -f "$CERT_PATH" ]]; then add_report_row "CERT_PATH" "missing" "FAIL" ""; export_html_report "Cert Install"; exit 1; fi
FP=$(openssl x509 -in "$CERT_PATH" -noout -fingerprint -sha256 2>/dev/null || openssl x509 -inform DER -in "$CERT_PATH" -noout -fingerprint -sha256 2>/dev/null || echo "unknown")
SUBJ=$(openssl x509 -in "$CERT_PATH" -noout -subject 2>/dev/null || openssl x509 -inform DER -in "$CERT_PATH" -noout -subject 2>/dev/null || echo "unknown")
log_info "Subject: $SUBJ"; log_info "SHA256: $FP"
CN=$(echo "$SUBJ" | sed -n 's/.*CN=\([^,/]*\).*/\1/p'); echo "$CN" > "$ROLLBACK_DIR/cn.txt"; echo "$FP" > "$ROLLBACK_DIR/fingerprint.txt"
EXT=${CERT_PATH##*.}; RC=1
if [[ "$EXT" == "p12" || "$EXT" == "pfx" ]]; then
  prompt_secret CERT_PASSWORD "Senha do P12" || { add_report_row "CERT_PASSWORD" "missing" "FAIL" ""; export_html_report "Cert Install"; exit 1; }
  if security import "$CERT_PATH" -k "$KEYCHAIN" -P "$CERT_PASSWORD" -T /usr/bin/codesign 2>&1 | tee -a "$LOG_FILE"; then RC=0; fi
  unset CERT_PASSWORD
else
  if [[ "$TRUST_ROOT" == "YES" ]]; then
    if [[ "$CONFIRM" != "YES" ]]; then add_report_row "trustRoot" "blocked" "FAIL" "$FP"; export_html_report "Cert Install"; exit 1; fi
    if security add-trusted-cert -d -r trustRoot -k "$KEYCHAIN" "$CERT_PATH" 2>&1 | tee -a "$LOG_FILE"; then RC=0; fi
  else
    if security add-certificates -k "$KEYCHAIN" "$CERT_PATH" 2>&1 | tee -a "$LOG_FILE"; then RC=0; fi
  fi
fi
if [[ $RC -eq 0 ]]; then
  add_report_row "install" "ok" "PASS" "$FP"
  echo "Rollback: security delete-certificate -c \"$CN\" \"$KEYCHAIN\"" > "$ROLLBACK_DIR/ROLLBACK.txt"
else
  add_report_row "install" "failed" "FAIL" "$FP"; export_html_report "Cert Install"; exit 1
fi
export_html_report "Certificate Install"