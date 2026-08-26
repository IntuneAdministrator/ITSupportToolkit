# Risk Inventory — IT Repair & Diagnostic Toolkit

**Owner:** Allester Padovani  
**Updated:** 2026-08-26  
**Policy:** Scripts marked **Dangerous** require ticket approval + operator confirmation before production use.

Risk levels: **Low** (read-only) · **Caution** (reversible change) · **Dangerous** (data loss / auth / trust / mass impact)

---

## Dangerous — run only with change control

| Script / area | Platform | Risk | Prerequisites | Operator warning |
|---------------|----------|------|---------------|------------------|
| `user-offboarding-disable-revoke-mac.sh` | macOS SA/IT | Dangerous | `CONFIRM=YES`, not console user, not last admin | Rotates password; hides account; snapshot in Logs/Backups |
| `certificate-install-cli-mac.sh` + `TRUST_ROOT=YES` | macOS SA/IT | Dangerous | `CONFIRM=YES`, review SHA256 fingerprint | Installs system trust root |
| `outlook-mac-profile-reset-mac.sh` | macOS SA/IT | Dangerous | User notified; Outlook closed | Deletes local Outlook profile after backup |
| `print-spool-reset-stuck-mac.sh` | macOS SA/IT | Caution→Dangerous at scale | None | Clears **all** CUPS jobs |
| `macos-updates-install-pending-mac.sh` | macOS SA/IT | Dangerous | Maintenance window | May reboot; installs all pending updates |
| `transfer-user-files-before-remove-mac.sh` | macOS SA/IT | Caution | `SOURCE_USER`, DEST under `/Users/Shared` | Copies PII to Shared |
| Windows Debloat / Remove-Appx packs | Windows | Dangerous | Backup + WhatIf first | Can remove business apps |
| `_Tools/**/Microsoft Windows Activation Scripts*` (MAS) | Windows | Dangerous | Legal entitlement only | Activation tooling — AV/policy sensitive |
| Imported M365 scripts with `-Password` | Win+Mac | Dangerous | Prefer cert/modern auth | Plaintext password on CLI historically |
| `session-revoke` / token revoke guides | Win+Mac | Dangerous | Identity admin | Signs user out of cloud sessions |
| Boot recovery / BCD / disk format class | Windows | Dangerous | Offline backup | Can render OS unbootable |
| Softwaredistribution / WU cache wipe | Windows | Caution | Disk space | Re-downloads updates |

---

## Caution — helpdesk with care

| Area | Notes |
|------|-------|
| Outlook/Teams/OneDrive cache clear (Mac) | Scoped `rm` under user Library; app must be quit |
| Printer remove/reinstall (`lpadmin`) | Needs URI; validate scheme `ipp/ipps/socket` |
| Create local user / add groups | Idempotent guards added; `ALLOW_ADMIN=1` required for admin group |
| Registry repairs (Win generated) | Prefer `-WhatIf`; confirm Backup-RegistryKey ran |
| Network stack reset / TCP-IP reset | Brief disconnect |

---

## Low — diagnostics

| Area | Notes |
|------|-------|
| FileVault / SIP / Gatekeeper **status** | Read-only |
| `softwareupdate -l`, inventory, event log audits | Read-only |
| Keychain certificate **list** / expiry report | Read-only |
| Hardware warranty / inventory collectors | Read-only |

---

## Accepted risks (documented)

1. **Embedded common library** in thousands of scripts — migration via `ConvertTo-SharedLibrary.ps1`; full rewrite deferred.
2. **Unsigned** `IT Repair & Diagnostic Toolkit.exe` / `MASTER-MENU.ps1` — accept until org code-signing cert applied (see CONTRIBUTING).
3. **SysAdmin ↔ ITSupport mirrors** of Imported + recent Mac packs — disk cost accepted for role UX; fix once and copy.
4. **Dry-run on macOS** — no universal `DRY_RUN` yet; Windows `-WhatIf` incomplete on ~227 stubs — tracked in CHANGELOG; smoke tool reports gaps.
5. **GUI elevates all `.sh` with sudo** — accepted for helpdesk simplicity; prefer least-privilege later.
6. **Config secret scan (closure):** 97 config-like files scanned — **0** plaintext password/token hits.

---

## Operator checklist (Dangerous)

1. Ticket ID recorded.
2. Backup / snapshot path known.
3. `CONFIRM=YES` (Mac) or GUI Dangerous dialog acknowledged (Windows).
4. Dry-run / WhatIf when supported.
5. Exit code verified (`0`/`1`).
6. HTML/transcript log attached to ticket.
