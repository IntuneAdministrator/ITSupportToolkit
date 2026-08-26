# Author: Allester Padovani
#!/usr/bin/env python3
"""IT Repair & Diagnostic Toolkit — cross-platform GUI.
Windows host: matches MASTER-MENU.ps1 -Gui. macOS host: Apple HIG-inspired chrome.
Force with --style windows|macos.
"""
from __future__ import annotations

import json
import os
import platform
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
import tkinter as tk
from tkinter import messagebox


def toolkit_root() -> Path:
    """Folder that contains Windows/, macOS/, and theme cfg.

    Dev: next to MASTER-MENU-GUI.py.
    Frozen .app (PyInstaller): parent of IT Repair & Diagnostic Toolkit.app so script libraries stay outside the bundle.
    """
    if getattr(sys, "frozen", False):
        exe = Path(sys.executable).resolve()
        # .../IT Repair & Diagnostic Toolkit.app/Contents/MacOS/<binary>
        if exe.parent.name == "MacOS" and exe.parent.parent.name == "Contents":
            return exe.parents[2].parent
        return exe.parent
    return Path(__file__).resolve().parent


ROOT = toolkit_root()
THEME_PREF = ROOT / "toolkit-theme.cfg"
THEME_PREF_LEGACY = ROOT / "gui-color-theme.txt"
PRODUCT_VERSION = "1.6.2"
BRAND = "IT Repair & Diagnostic Toolkit"
TAGLINE = "Windows & macOS · SysAdmin & IT Support"

THEME_ORDER = [
    "Break & Fix", "Networking", "Antivirus & Security", "Microsoft 365",
    "Identity & Access", "MDM & Endpoint", "Devices & Peripherals", "Storage & Backup",
    "Updates & Patching", "Remote Access", "Performance & Diagnostics", "Print Services",
    "Cloud & Virtualization", "Apps & Browser", "Onboarding & Lifecycle",
    "Evidence & Reporting", "Other",
]

# Windows chrome = MASTER-MENU.ps1; macOS chrome = Apple HIG-inspired (auto by host OS)
PALETTES_WINDOWS = {
    "Dark": {
        "WindowBg": "#0b0f17", "PanelBg": "#121826", "PanelBorder": "#1e293b",
        "TextPrimary": "#e2e8f0", "TextSecondary": "#a0aec0", "TextMuted": "#718096",
        "TextTitle": "#63b3ed", "TextSection": "#90cdf4", "TextAccent": "#f6ad55",
        "InputBg": "#1a1f2e", "InputBorder": "#2d3748", "InputFg": "#e2e8f0",
        "BtnSecondaryBg": "#2d3748", "BtnSecondaryFg": "#e2e8f0", "BtnSecondaryHover": "#3d4a5c",
        "BtnDryRunBg": "#744210", "BtnDryRunFg": "#faf089", "BtnDryRunHover": "#8b5a12",
        "BtnRunBg": "#2b6cb0", "BtnRunFg": "#ffffff", "BtnRunHover": "#3182ce", "BtnRunBorder": "#63b3ed",
        "OutputBg": "#0b0f17", "OutputFg": "#a0aec0",
        "ListSelected": "#2b4c7e", "ListHover": "#232a3b",
        "HintOk": "#68d391", "HintWarn": "#f6ad55",
        "ThemeBtnBg": "#121826", "ThemeBtnFg": "#ffffff", "ThemeBtnBorder": "#2d3748", "ThemeBtnHover": "#1a2332",
        "RadioSelect": "#1a1f2e",
    },
    "Light": {
        "WindowBg": "#f0f4f8", "PanelBg": "#ffffff", "PanelBorder": "#d0d7de",
        "TextPrimary": "#0f172a", "TextSecondary": "#334155", "TextMuted": "#64748b",
        "TextTitle": "#1d4ed8", "TextSection": "#1e40af", "TextAccent": "#b45309",
        "InputBg": "#ffffff", "InputBorder": "#94a3b8", "InputFg": "#0f172a",
        "BtnSecondaryBg": "#e2e8f0", "BtnSecondaryFg": "#0f172a", "BtnSecondaryHover": "#cbd5e1",
        "BtnDryRunBg": "#fef3c7", "BtnDryRunFg": "#92400e", "BtnDryRunHover": "#fde68a",
        "BtnRunBg": "#2563eb", "BtnRunFg": "#ffffff", "BtnRunHover": "#1d4ed8", "BtnRunBorder": "#1e40af",
        "OutputBg": "#f8fafc", "OutputFg": "#334155",
        "ListSelected": "#bfdbfe", "ListHover": "#e2e8f0",
        "HintOk": "#15803d", "HintWarn": "#c2410c",
        "ThemeBtnBg": "#eef2f7", "ThemeBtnFg": "#1e293b", "ThemeBtnBorder": "#334155", "ThemeBtnHover": "#dde4ed",
        "RadioSelect": "#ffffff",
    },
}

# macOS Settings / Sequoia inspired — title is near-black; blue only for accents/actions
PALETTES_MACOS = {
    "Dark": {
        "WindowBg": "#1c1c1e", "PanelBg": "#2c2c2e", "PanelBorder": "#48484a",
        "TextPrimary": "#f5f5f7", "TextSecondary": "#a1a1a6", "TextMuted": "#8e8e93",
        "TextTitle": "#f5f5f7", "TextSection": "#98989d", "TextAccent": "#98989d",
        "InputBg": "#3a3a3c", "InputBorder": "#636366", "InputFg": "#f5f5f7",
        "BtnSecondaryBg": "#3a3a3c", "BtnSecondaryFg": "#f5f5f7", "BtnSecondaryHover": "#48484a",
        "BtnDryRunBg": "#3a2f00", "BtnDryRunFg": "#ffd60a", "BtnDryRunHover": "#4a3d00",
        "BtnRunBg": "#0a84ff", "BtnRunFg": "#ffffff", "BtnRunHover": "#409cff", "BtnRunBorder": "#0a84ff",
        "OutputBg": "#1c1c1e", "OutputFg": "#a1a1a6",
        "ListSelected": "#0a84ff", "ListHover": "#3a3a3c",
        "HintOk": "#30d158", "HintWarn": "#ff9f0a",
        "ThemeBtnBg": "#3a3a3c", "ThemeBtnFg": "#f5f5f7", "ThemeBtnBorder": "#636366", "ThemeBtnHover": "#48484a",
        "RadioSelect": "#3a3a3c",
    },
    "Light": {
        "WindowBg": "#f2f2f7", "PanelBg": "#ffffff", "PanelBorder": "#d1d1d6",
        "TextPrimary": "#1d1d1f", "TextSecondary": "#6e6e73", "TextMuted": "#8e8e93",
        "TextTitle": "#1d1d1f", "TextSection": "#8e8e93", "TextAccent": "#8e8e93",
        "InputBg": "#ffffff", "InputBorder": "#c7c7cc", "InputFg": "#1d1d1f",
        "BtnSecondaryBg": "#e5e5ea", "BtnSecondaryFg": "#1d1d1f", "BtnSecondaryHover": "#d8d8dc",
        "BtnDryRunBg": "#fff6df", "BtnDryRunFg": "#9a6700", "BtnDryRunHover": "#ffecc2",
        "BtnRunBg": "#007aff", "BtnRunFg": "#ffffff", "BtnRunHover": "#0066d6", "BtnRunBorder": "#007aff",
        "OutputBg": "#ffffff", "OutputFg": "#6e6e73",
        "ListSelected": "#007aff", "ListHover": "#f2f2f7",
        "HintOk": "#248a3d", "HintWarn": "#c93400",
        "ThemeBtnBg": "#e5e5ea", "ThemeBtnFg": "#1d1d1f", "ThemeBtnBorder": "#c7c7cc", "ThemeBtnHover": "#d8d8dc",
        "RadioSelect": "#ffffff",
    },
}


def resolve_ui_style(requested: str | None = None) -> str:
    """windows | macos — auto picks from host OS."""
    if requested in ("windows", "macos"):
        return requested
    return "macos" if sys.platform == "darwin" else "windows"


def ui_palettes(style: str) -> dict:
    return PALETTES_MACOS if style == "macos" else PALETTES_WINDOWS


def ui_fonts(style: str) -> dict[str, tuple]:
    """Font tuples for Tk. Prefer SF / Helvetica on macOS chrome; Segoe on Windows chrome."""
    import tkinter.font as tkfont

    families = {f.lower(): f for f in tkfont.families()}

    def pick(*names: str, fallback: str = "Arial") -> str:
        for n in names:
            if n.lower() in families:
                return families[n.lower()]
        return fallback

    # MASTER-MENU.ps1 XAML sizes (WPF DIPs). Tk/Segoe draws larger than WPF at
    # the same point size — scale for visual parity. List columns need a bit
    # more reduction so THEME/CATEGORY/SCRIPTS match the WPF ListBox look.
    def sz(wpf_pt: int) -> int:
        return max(8, int(round(wpf_pt * 0.85)))

    def list_sz(wpf_pt: int) -> int:
        return max(8, int(round(wpf_pt * 0.77)))

    if style == "macos":
        base = pick("SF Pro Text", "SF Pro Display", ".AppleSystemUIFont", "Helvetica Neue", "Segoe UI", fallback="Arial")
        mono = pick("Menlo", "SF Mono", "Consolas", fallback="Courier New")
        return {
            "title": (base, sz(20), "bold"),
            "subtitle": (base, sz(12)),
            "search_lbl": (base, sz(13)),
            "section": (base, sz(11), "bold"),
            "body": (base, sz(14)),
            "body_sm": (base, sz(12)),
            "list": (base, list_sz(13)),
            "btn": (base, sz(12)),
            "btn_bold": (base, sz(12), "bold"),
            "mono": (mono, sz(12)),
            "dot": (base, list_sz(11)),
            "info": (base, list_sz(13), "bold"),
        }
    base = pick("Segoe UI Semibold", "Segoe UI", fallback="Arial")
    body = pick("Segoe UI", fallback="Arial")
    return {
        "title": (base, sz(20)) if "semibold" in base.lower() else (body, sz(20), "bold"),
        "subtitle": (body, sz(12)),
        "search_lbl": (base, sz(13)) if "semibold" in base.lower() else (body, sz(13), "bold"),
        "section": (body, sz(11), "bold"),
        "body": (body, sz(14)),
        "body_sm": (body, sz(12)),
        "list": (body, list_sz(13)),
        "btn": (body, sz(12)),
        "btn_bold": (base, sz(12)) if "semibold" in base.lower() else (body, sz(12), "bold"),
        "mono": (pick("Consolas", "Courier New"), sz(12)),
        "dot": (body, list_sz(11)),
        "info": (body, list_sz(13), "bold"),
    }


def ui_metrics(style: str) -> dict[str, int]:
    # Theme/Category use WPF MinWidth (220/280) — fixed widths so they don't
    # leave a big empty strip on the right; Scripts takes the rest (*).
    common = {
        "card_radius": 12, "btn_radius": 10, "pill_radius": 17,
        "search_radius": 17, "output_radius": 8, "pad": 14,
        "card_padx": 10, "card_pady": 10,
        "plat_padx": 12, "plat_pady": 12,
        "status_padx": 12, "status_pady": 12,
        "search_w": 280, "btn_h": 34,
        "theme_col": 280, "cat_col": 360, "row_pad": 3,
        "status_h": 130,
    }
    if style == "macos":
        return {**common, "theme_btn_w": 140}
    return {**common, "theme_btn_w": 132}


# Back-compat alias used in a few places
PALETTES = PALETTES_WINDOWS


# ── catalog helpers (unchanged logic) ───────────────────────────────────────

def theme_for(folder: str) -> str:
    n = folder.lower()
    rules = [
        ("Microsoft 365", r"imported-m365|m365-audit|m365-repair|audit-report"),
        ("Devices & Peripherals", r"imported-tech-support|tech-support-tools|troubleshoot"),
        ("Break & Fix", r"imported-windows-repair|imported-windows-settings"),
        ("Microsoft 365", r"m365|office|outlook|teams|onedrive|sharepoint|exchange|graph|email|calendar|collaboration|cloud-storage|mailbox"),
        ("Antivirus & Security", r"malware|antivirus|edr|security|harden|firewall|asr|awareness|phishing|xprotect|gatekeeper|defender|filevault|sip-"),
        ("Identity & Access", r"certificate|keychain|pkcs|ssl-tls|cert-"),
        ("Networking", r"network|dns|dhcp|vpn|connectivity|wifi|wireless|proxy|tcp|mtu|nrpt|aovpn|directaccess|bonjour"),
        ("Identity & Access", r"identity|mfa|account|active-directory|entra|azure-ad|hello|credential|sso|unlock|password|signin|sign-in|auth|pim|ca-block|legacy-auth"),
        ("Evidence & Reporting", r"runbook|intunewin|jamf-policy-template|jamf-self-service|intune-mac-runbook"),
        ("Onboarding & Lifecycle", r"cmdb|inventory-export|servicenow|snipeit|lansweeper|asset-panda|tenant-device|endpoint-analytics"),
        ("Storage & Backup", r"raid|iscsi|san-|storage-spaces|refs|hyper-v-host|vss-|megaraid|apfs-container|parallels-vm|vmware-fusion|timemachine-server|backup-vss"),
        ("Devices & Peripherals", r"kvm|aten|raritan|avocent|zebra|scanner|rfid|receipt-printer|powermic|stream-deck|piv|smartcard|yubikey|magtek|dictation|plotter|spacepilot|barcode|dock-firmware|wd19|caldigit|apple-silicon|magic-keyboard|warranty-lookup|gpu|quadro|nvidia-smi|egpu|thunderbolt-raid"),
        ("MDM & Endpoint", r"intune|jamf|autopilot|sccm|mecm|compliance|mdm|enrollment|purview|secure-score|dlp|intunewin|graph-mac|entra-mac"),
        ("Devices & Peripherals", r"usb|bluetooth|audio|video|webcam|display|hardware|dock|peripheral|laptop|battery|power|warranty|inventory|font|language|region|finder|spotlight|magic|headset|sd-card"),
        ("Storage & Backup", r"disk|storage|backup|vss|apfs|timemachine|time-machine|shadow|refs|spaces"),
        ("Updates & Patching", r"update|wsus|softwareupdate|patch|catalog"),
        ("Remote Access", r"rdp|remote-access|remote-tools|ard|ssh|remote-work|home-office|screensharing|vnc"),
        ("Performance & Diagnostics", r"performance|telemetry|event-log|diagnostic|crash|slow-|process-service"),
        ("Print Services", r"print|cups|spooler"),
        ("Cloud & Virtualization", r"hyper-v|w365|cloud-pc|avd|virtual|docker|fslogix"),
        ("Apps & Browser", r"browser|app-compat|appx|store|app-management|shim"),
        ("Onboarding & Lifecycle", r"onboarding|offboarding|eol|migration|licensing|activation"),
        ("Evidence & Reporting", r"evidence|reporting"),
        ("Break & Fix", r"quick-fix|slow-pc|slow-mac|settings-repair|system-repair|system-information|file-repair|explorer|startup|login|boot|file-explorer|shell"),
    ]
    for label, pat in rules:
        if re.search(pat, n):
            return label
    return "Other"


def _split_script_name_words(stem: str) -> list[str]:
    """Split kebab/snake and PascalCase stems into display words."""
    words: list[str] = []
    for chunk in (c for c in re.split(r"[-_]+", stem) if c):
        parts = re.findall(r"[A-Z]+(?=[A-Z][a-z]|[0-9]|$)|[A-Z]?[a-z]+|[0-9]+", chunk)
        words.extend(parts if parts else [chunk])
    return words


def script_ui(path: Path) -> dict:
    """Unique, detailed helpdesk label + risk + technician info text per script."""
    stem = path.stem
    n = stem.lower()
    words = _split_script_name_words(stem)
    # Drop platform tokens anywhere; filename at end still guarantees uniqueness
    words = [w for w in words if w.lower() not in ("mac", "win", "client")]
    if not words:
        words = _split_script_name_words(stem)
    topic_parts = []
    for w in words:
        if w.isupper() or (len(w) <= 4 and w.isalpha() and w.upper() == w):
            topic_parts.append(w.upper() if len(w) <= 4 else w)
        elif re.fullmatch(r"[A-Za-z0-9]+", w):
            topic_parts.append(w[:1].upper() + w[1:].lower() if len(w) > 1 else w.upper())
        else:
            topic_parts.append(w)
    topic = " ".join(topic_parts)

    risk = "Low"
    care = (
        "Read-only / diagnostic. Low impact. Safe to run for troubleshooting; "
        "still confirm you selected the correct user/device."
    )
    if any(k in n for k in ("wipe", "destroy", "format", "diskpart", "purge", "delete", "revoke",
                            "quarantine", "softwaredistribution-reset", "csc-reset", "bcd-",
                            "session-revoke", "thinlocal", "boot-recovery", "litigation-hold")):
        risk = "Dangerous"
        care = (
            "MAY DELETE DATA OR BREAK SIGN-IN. Open a ticket, notify the user, take a backup when "
            "possible, prefer Dry Run first. Do not run at scale without approval. Confirm asset "
            "tag / username before continuing."
        )
    elif any(k in n for k in ("reset", "repair", "fix", "flush", "clear", "rebuild", "force",
                              "purge", "resync", "cache", "token-clear", "license-reset",
                              "reinstall", "restart", "cleanup")):
        risk = "Caution"
        care = (
            "Changes config/cache. Close the affected app, notify the user, document changes, "
            "and have rollback ready. Verify the symptom matches this script before running."
        )

    if re.search(r"all-in-one-triage|one-click-common", n):
        action, detail = "Triage", "automatic common-issue checks and basic repairs"
    elif re.search(r"whatif|guide|hint|prep|path-hint|portal", n):
        action, detail = "Guide", "reference / prep (minimal or no system change)"
    elif re.search(r"check|status|audit|report|detect|lookup|inventory|snapshot|digest|export", n):
        action, detail = "Check", "diagnostic / report"
    elif re.search(r"flush|clear|purge", n):
        action, detail = "Clear", "clears cache or temporary data"
    elif re.search(r"reset|repair|fix|rebuild|stack-reset|auto-repair|quick-fix", n):
        action, detail = "Repair", "repairs or resets the component"
    elif re.search(r"force|renew|kickstart", n):
        action, detail = "Force", "forces refresh or renewal"
    elif re.search(r"launch-", n):
        action, detail = "Launch", "opens imported tech-support tool"
    elif re.search(r"connect|install", n):
        action, detail = "Setup", "connection, install, or prep"
    else:
        action, detail = "Tool", "run this script for the named area"

    ext = path.suffix.lower().lstrip(".")
    plat = "Mac" if n.endswith("-mac") or ext == "sh" else ("Win" if ext == "ps1" else ext.upper())
    label = f"[{action}] {topic} - {detail} ({plat}, {path.name})"
    if len(label) > 220:
        label = label[:217] + "..."

    risk_meaning = {
        "Dangerous": (
            "HIGH IMPACT (red dot) — can delete data, break sign-in, wipe config, or change security posture. "
            "Treat like a change ticket."
        ),
        "Caution": (
            "CHANGES CONFIG (yellow dot) — modifies settings, cache, services, profiles, or app state. "
            "User may notice a restart or re-login."
        ),
        "Low": (
            "SAFE / DIAGNOSTIC (green dot) — mainly read-only checks, reports, or low-impact tools. "
            "Still confirm the correct target first."
        ),
    }[risk]

    summaries = {
        "Triage": (
            f"This is an automated triage helper for '{topic}'.\n"
            "It runs a bundle of common checks and may apply light, well-known fixes so you can narrow "
            "the incident faster without jumping between many menus.\n"
            "Use it early in a ticket when the symptom is broad and you need a structured first pass."
        ),
        "Guide": (
            f"This opens guidance / prep steps for '{topic}' with minimal or no system change ({detail}).\n"
            "Use it when you need the correct portal path, prerequisites, or a checklist before a repair.\n"
            "Safest place to start if you are unsure which repair to pick."
        ),
        "Check": (
            f"This collects diagnostic information or a report about '{topic}' ({detail}).\n"
            "Use it to confirm root cause, gather ticket evidence, and decide whether Clear / Repair / Force is needed.\n"
            "Prefer Check before Repair whenever the symptom is unclear."
        ),
        "Clear": (
            f"This clears cache or temporary data related to '{topic}'.\n"
            "Typical outcomes: corrupted local cache removed, app forced to rebuild local state, or stale tokens discarded.\n"
            "User may need to reopen the app, re-authenticate, or wait for re-sync. Save their work first."
        ),
        "Repair": (
            f"This attempts to repair or reset '{topic}' ({detail}).\n"
            "Expect configuration, service, profile, or client-stack changes. Stronger than Clear — follow a confirmed diagnosis.\n"
            "Have rollback (restore point, re-login, known-good profile, or Dry Run) before elevating."
        ),
        "Force": (
            f"This forces a refresh or renewal for '{topic}' (sync, license, policy, connection, or similar).\n"
            "It can briefly interrupt the related app or session. Use when a normal retry is stuck and Check shows the component is unhealthy."
        ),
        "Launch": (
            f"This launches an imported tech-support tool focused on '{topic}'.\n"
            "You leave the launcher and enter another UI — read that tool's prompts before applying changes. Do not assume read-only."
        ),
        "Setup": (
            f"This performs connection, install, or prep work for '{topic}' ({detail}).\n"
            "Confirm network access, account permissions, and required modules/licenses first."
        ),
        "Tool": (
            f"This runs the toolkit script for '{topic}' ({detail}).\n"
            "Read the risk level and care notes before Dry Run or Run Elevated. If the label does not match the ticket, stop."
        ),
    }
    summary = summaries.get(action, summaries["Tool"])

    when_to_use = {
        "Triage": "First-pass / unknown root cause; structured sweep of common failure points.",
        "Guide": "Before changing anything; instructions, portal steps, or prerequisites.",
        "Check": "To prove the issue, capture evidence, or choose the next repair safely.",
        "Clear": "When cache/temp state is suspected (stuck sign-in, stale data, corrupt local app state).",
        "Repair": "When diagnosis already points to a broken component that needs reset/rebuild.",
        "Force": "When a sync/license/policy refresh is stuck and Check shows it is not updating.",
        "Launch": "When a specialized imported tool is the right next step for this topic.",
        "Setup": "When installing, connecting, or preparing the named service/client.",
        "Tool": "When the script topic matches the ticket and you understand the risk level.",
    }[action]

    expect = {
        "Dangerous": "Possible data loss, sign-in impact, or security change. User communication and approval are mandatory.",
        "Caution": "App restart, re-login, short downtime, or visible config change is normal.",
        "Low": "Mostly information on screen / in STATUS. Little lasting change if it is a pure Check/Guide.",
    }[risk]

    info_tip = (
        f"{summary}\n\nWhen to use: {when_to_use}\n"
        f"Risk: {risk} — {risk_meaning}\n\nCare: {care}\n\nFile: {path.name} ({plat})"
    )
    info_text = (
        "SCRIPT INFORMATION — read carefully before Dry Run or Run Elevated\n\n"
        "══════════════════════════════════════════════════════════════\n"
        "1) WHAT THIS SCRIPT DOES\n"
        "══════════════════════════════════════════════════════════════\n"
        f"{summary}\n\n"
        f"List label in SCRIPTS:\n{label}\n\n"
        "══════════════════════════════════════════════════════════════\n"
        "2) WHEN A TECHNICIAN SHOULD USE IT\n"
        "══════════════════════════════════════════════════════════════\n"
        f"{when_to_use}\n\n"
        "Do NOT use it if:\n"
        f"  • The ticket symptom does not match '{topic}'\n"
        "  • You have not identified the correct user / device / mailbox / tenant\n"
        "  • A safer Check or Guide script exists and you have not tried it yet (when applicable)\n\n"
        "══════════════════════════════════════════════════════════════\n"
        "3) RISK LEVEL (matches the colored dot)\n"
        "══════════════════════════════════════════════════════════════\n"
        f"{risk} — {risk_meaning}\n\n"
        "Legend:\n"
        "  • Green  = safe / diagnostic (Low)\n"
        "  • Yellow = changes config (Caution)\n"
        "  • Red    = high impact (Dangerous)\n\n"
        f"Expected impact after running:\n{expect}\n\n"
        "══════════════════════════════════════════════════════════════\n"
        "4) CARE / PRECAUTIONS (checklist)\n"
        "══════════════════════════════════════════════════════════════\n"
        f"{care}\n\n"
        "Technician checklist before Run Elevated:\n"
        "  [ ] Correct PLATFORM selected (Windows vs macOS)\n"
        "  [ ] Correct ROLE selected (SysAdmin vs IT Support)\n"
        "  [ ] Correct user / device / ticket confirmed\n"
        "  [ ] User notified if the app may close or they may need to sign in again\n"
        "  [ ] Dry Run (Preview) used first when the script supports it\n"
        "  [ ] Rollback plan ready (restore point, backup, known-good profile, or reinstall path)\n\n"
        "══════════════════════════════════════════════════════════════\n"
        "5) FILE / PLATFORM\n"
        "══════════════════════════════════════════════════════════════\n"
        f"File name : {path.name}\n"
        f"Platform  : {plat}\n"
        f"Action tag: {action}\n"
        f"Topic     : {topic}\n"
        f"Full path :\n{path}\n\n"
        "Tip: keep this window open while you brief the user. Prefer Dry Run, then Run Elevated only after the preview looks correct."
    )

    return {
        "label": label,
        "list_text": label,
        "risk": risk,
        "care": care,
        "summary": summary,
        "info_tip": info_tip,
        "info_text": info_text,
        "file": path.name,
        "action": action,
        "topic": topic,
    }


RISK_DOT = {
    "Dangerous": "#fc8181",
    "Caution": "#ecc94b",
    "Low": "#48bb78",
}
RISK_DOT_MACOS = {
    "Dangerous": "#ff453a",
    "Caution": "#ffd60a",
    "Low": "#30d158",
}


def find_pwsh() -> str | None:
    for name in ("pwsh", "pwsh.exe"):
        p = shutil.which(name)
        if p:
            return p
    return None


def discover() -> list[dict]:
    catalog: list[dict] = []
    for platform_name, base, exts in (
        ("Windows", ROOT / "Windows", {".ps1"}),
        ("macOS", ROOT / "macOS", {".sh", ".ps1"}),
    ):
        if not base.is_dir():
            continue
        for role, role_label in (("SysAdmin", "System Administrator"), ("ITSupport", "IT Support")):
            role_dir = base / role
            if not role_dir.is_dir():
                continue
            for cat in sorted(role_dir.iterdir()):
                if not cat.is_dir() or cat.name.startswith("."):
                    continue
                scripts = sorted(p for p in cat.iterdir() if p.is_file() and p.suffix.lower() in exts)
                scripts_meta = []
                seen_labels: dict[str, int] = {}
                for s in scripts:
                    ui = script_ui(s)
                    lab = ui["label"]
                    if lab in seen_labels:
                        seen_labels[lab] += 1
                        ui["label"] = f"{lab} #{seen_labels[lab]}"
                        ui["list_text"] = ui["label"]
                    else:
                        seen_labels[lab] = 1
                    scripts_meta.append({"name": s.stem, "path": str(s), **ui})
                catalog.append({
                    "platform": platform_name, "role": role, "role_label": role_label,
                    "name": cat.name, "display": cat.name.split("_", 1)[-1].replace("-", " "),
                    "theme": theme_for(cat.name), "path": str(cat),
                    "scripts": scripts_meta,
                    "count": len(scripts_meta),
                })
    return catalog


def catalog_stats(catalog: list[dict]) -> tuple[int, int, int]:
    win = sum(c["count"] for c in catalog if c["platform"] == "Windows")
    mac = sum(c["count"] for c in catalog if c["platform"] == "macOS")
    return win, mac, len(catalog)


# ── window placement (always same center — stack GUIs on top of each other) ─

def center_on_screen(win: tk.Misc, width: int | None = None, height: int | None = None) -> None:
    """Place window in the middle of the primary screen (fixed spot, no cascade offset)."""
    try:
        win.update_idletasks()
    except tk.TclError:
        return
    w = int(width if width is not None else max(win.winfo_reqwidth(), win.winfo_width(), 1))
    h = int(height if height is not None else max(win.winfo_reqheight(), win.winfo_height(), 1))
    sw = int(win.winfo_screenwidth())
    sh = int(win.winfo_screenheight())
    x = max(0, (sw - w) // 2)
    y = max(0, (sh - h) // 2)
    win.geometry(f"{w}x{h}+{x}+{y}")
    try:
        win.lift()
        win.focus_force()
    except tk.TclError:
        pass


# ── silent wide script-info dialog (no system beep) ─────────────────────────

def show_script_info_dialog(parent: tk.Misc, body: str, *, title: str = "Script information",
                            bg: str = "#0b0f17", panel: str = "#121826", fg: str = "#e2e8f0",
                            title_fg: str = "#63b3ed", btn_bg: str = "#2b6cb0", btn_fg: str = "#ffffff") -> None:
    """Wide technician briefing window — silent (never uses messagebox beep)."""
    win = tk.Toplevel(parent)
    win.title(title)
    win.configure(bg=bg)
    win.minsize(720, 420)
    win.transient(parent)
    win.grab_set()
    # Suppress Tk bell if anything triggers it
    win.bell = lambda *a, **k: None  # type: ignore[method-assign]
    center_on_screen(win, 860, 560)

    outer = tk.Frame(win, bg=bg, padx=16, pady=16)
    outer.pack(fill="both", expand=True)

    tk.Label(
        outer, text="Technician briefing — read before Dry Run / Run Elevated",
        bg=bg, fg=title_fg, font=("Segoe UI", 12, "bold"), anchor="w", justify="left",
        wraplength=800,
    ).pack(fill="x", pady=(0, 10))

    card = tk.Frame(outer, bg=panel, highlightthickness=1, highlightbackground="#2d3748")
    card.pack(fill="both", expand=True)

    text = tk.Text(
        card, wrap="word", relief="flat", bd=0, padx=12, pady=12,
        bg=panel, fg=fg, insertbackground=fg, font=("Consolas", 11),
        highlightthickness=0,
    )
    sb = tk.Scrollbar(card, orient="vertical", command=text.yview)
    text.configure(yscrollcommand=sb.set)
    sb.pack(side="right", fill="y")
    text.pack(side="left", fill="both", expand=True)
    text.insert("1.0", body)
    text.configure(state="disabled")

    def close(_e=None) -> None:
        try:
            win.grab_release()
        except tk.TclError:
            pass
        win.destroy()

    bar = tk.Frame(outer, bg=bg)
    bar.pack(fill="x", pady=(12, 0))
    ok = tk.Button(
        bar, text="OK", width=14, command=close, relief="flat", bd=0,
        bg=btn_bg, fg=btn_fg, activebackground=btn_bg, activeforeground=btn_fg,
        font=("Segoe UI", 10, "bold"), cursor="hand2",
    )
    ok.pack(side="right")
    win.bind("<Return>", close)
    win.bind("<Escape>", close)
    win.protocol("WM_DELETE_WINDOW", close)
    center_on_screen(win, 860, 560)
    ok.focus_set()
    parent.wait_window(win)

def _round_rect(canvas: tk.Canvas, x1: int, y1: int, x2: int, y2: int, r: int, **kwargs):
    """Smooth rounded rectangle (higher splinesteps = more professional corners)."""
    r = max(0, min(r, (x2 - x1) // 2, (y2 - y1) // 2))
    if r <= 0:
        return canvas.create_rectangle(x1, y1, x2, y2, **kwargs)
    points = [
        x1 + r, y1,
        x2 - r, y1,
        x2, y1, x2, y1 + r,
        x2, y2 - r,
        x2, y2, x2 - r, y2,
        x1 + r, y2,
        x1, y2, x1, y2 - r,
        x1, y1 + r,
        x1, y1,
    ]
    kwargs.setdefault("splinesteps", 48)
    return canvas.create_polygon(points, smooth=True, **kwargs)


class RoundedCard(tk.Frame):
    """WPF-like data card (CornerRadius 12).

    Content lives in a real packed Frame (not Canvas.create_window), so listboxes
    and radios get normal geometry and stay visible.
    """

    def __init__(self, master, *, radius: int = 12, fill: str = "#121826",
                 border: str = "#1e293b", canvas_bg: str = "#0b0f17",
                 padx: int = 12, pady: int = 10, **kw):
        super().__init__(master, bg=canvas_bg, highlightthickness=0, bd=0, **kw)
        self._radius = radius
        self._fill = fill
        self._border = border
        self._canvas_bg = canvas_bg
        self._padx = padx
        self._pady = pady
        # Decorative rounded border behind content
        self._cv = tk.Canvas(self, highlightthickness=0, bd=0, bg=canvas_bg)
        self._cv.place(x=0, y=0, relwidth=1, relheight=1)
        self.inner = tk.Frame(self, bg=fill, highlightthickness=0, bd=0)
        self.inner.pack(fill="both", expand=True, padx=padx, pady=pady)
        self.bind("<Configure>", self._on_configure)

    def _on_configure(self, _event=None) -> None:
        # Draw after layout settles so size is real
        self.after_idle(self._redraw)

    def set_colors(self, *, fill: str, border: str, canvas_bg: str) -> None:
        self._fill, self._border, self._canvas_bg = fill, border, canvas_bg
        self.configure(bg=canvas_bg)
        self._cv.configure(bg=canvas_bg)
        self.inner.configure(bg=fill)
        self._redraw()

    def _redraw(self) -> None:
        w = max(self.winfo_width(), 2)
        h = max(self.winfo_height(), 2)
        self._cv.delete("shape")
        _round_rect(
            self._cv, 1, 1, w - 2, h - 2, self._radius,
            fill=self._fill, outline=self._border, width=1, tags="shape",
        )
        # Keep chrome behind the packed inner frame
        try:
            self._cv.tag_lower("shape")
            self._cv.lower()
        except tk.TclError:
            pass


class RoundedButton(tk.Canvas):
    """Rounded action / theme button (never assigns self._w)."""

    def __init__(self, master, *, text: str, command=None, radius: int = 10,
                 fill: str = "#2d3748", fg: str = "#e2e8f0", border: str = "#2d3748",
                 hover: str | None = None, canvas_bg: str = "#0b0f17",
                 width: int = 120, height: int = 36, font=("Segoe UI", 10), **kw):
        super().__init__(master, width=width, height=height, highlightthickness=0, bd=0,
                         bg=canvas_bg, cursor="hand2", **kw)
        self._bw, self._bh = width, height
        self._radius = radius
        self._fill = fill
        self._fg = fg
        self._border = border
        self._hover = hover or fill
        self._canvas_bg = canvas_bg
        self._text = text
        self._font = font
        self._command = command
        self._enabled = True
        self._disabled_command = None
        self._shape = None
        self._label = None
        self.bind("<Configure>", self._redraw)
        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
        self.bind("<Button-1>", self._on_click)
        self._redraw()

    def set_style(self, *, fill: str, fg: str, border: str, hover: str, canvas_bg: str,
                  text: str | None = None, font=None) -> None:
        self._fill, self._fg, self._border, self._hover = fill, fg, border, hover
        self._canvas_bg = canvas_bg
        self.configure(bg=canvas_bg)
        if text is not None:
            self._text = text
        if font is not None:
            self._font = font
        self._redraw()

    def set_enabled(self, enabled: bool, *, disabled_command=None) -> None:
        self._enabled = enabled
        self._disabled_command = disabled_command
        super().configure(cursor="hand2" if enabled else "arrow")
        self._redraw()

    def _redraw(self, _event=None) -> None:
        w = max(self.winfo_width(), self._bw, 2)
        h = max(self.winfo_height(), self._bh, 2)
        self.delete("all")
        # Stronger fade when disabled so it is obvious
        fill = self._fill if self._enabled else self._mix(self._fill, self._canvas_bg, 0.55)
        fg = self._fg if self._enabled else self._mix(self._fg, self._canvas_bg, 0.55)
        border = self._border if self._enabled else self._mix(self._border, self._canvas_bg, 0.4)
        self._shape = _round_rect(self, 1, 1, w - 2, h - 2, self._radius,
                                  fill=fill, outline=border, width=1)
        self._label = self.create_text(w // 2, h // 2, text=self._text, fill=fg, font=self._font)

    def _on_enter(self, _e=None) -> None:
        if self._enabled and self._shape:
            self.itemconfigure(self._shape, fill=self._hover)

    def _on_leave(self, _e=None) -> None:
        if self._shape:
            fill = self._fill if self._enabled else self._mix(self._fill, self._canvas_bg, 0.55)
            self.itemconfigure(self._shape, fill=fill)

    def _on_click(self, _e=None) -> None:
        if self._enabled and self._command:
            self._command()
        elif (not self._enabled) and getattr(self, "_disabled_command", None):
            self._disabled_command()

    @staticmethod
    def _mix(a: str, b: str, t: float) -> str:
        def hex_to_rgb(h: str):
            h = h.lstrip("#")
            return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
        ra, ga, ba = hex_to_rgb(a)
        rb, gb, bb = hex_to_rgb(b)
        return f"#{int(ra+(rb-ra)*t):02x}{int(ga+(gb-ga)*t):02x}{int(ba+(bb-ba)*t):02x}"


class RoundedSearch(tk.Frame):
    """Pill search box with optional placeholder (macOS-style)."""

    def __init__(self, master, *, textvariable: tk.StringVar, canvas_bg: str = "#0b0f17",
                 fill: str = "#1a1f2e", border: str = "#2d3748", fg: str = "#e2e8f0",
                 width: int = 280, height: int = 34, radius: int = 17,
                 placeholder: str = "", placeholder_fg: str = "#8e8e93"):
        super().__init__(master, bg=canvas_bg, highlightthickness=0, bd=0)
        self._radius = radius
        self._fill = fill
        self._border = border
        self._fg = fg
        self._canvas_bg = canvas_bg
        self._bw, self._bh = width, height
        self._placeholder = placeholder
        self._placeholder_fg = placeholder_fg
        self._var = textvariable
        self._showing_ph = False
        self._cv = tk.Canvas(self, width=width, height=height, highlightthickness=0, bd=0, bg=canvas_bg)
        self._cv.pack()
        self.entry = tk.Entry(
            self._cv, textvariable=textvariable, font=("Segoe UI", 10),
            relief="flat", bd=0, highlightthickness=0,
            bg=fill, fg=fg, insertbackground=fg,
        )
        self._win = self._cv.create_window(16, height // 2, anchor="w", window=self.entry)
        self._cv.bind("<Configure>", self._redraw)
        if placeholder:
            self.entry.bind("<FocusIn>", self._clear_placeholder)
            self.entry.bind("<FocusOut>", self._restore_placeholder)
            self._restore_placeholder()
        self._redraw()

    def _clear_placeholder(self, _e=None) -> None:
        if self._showing_ph:
            self._showing_ph = False
            self._var.set("")
            self.entry.configure(fg=self._fg)

    def _restore_placeholder(self, _e=None) -> None:
        if self._placeholder and not self._var.get():
            self._showing_ph = True
            self._var.set(self._placeholder)
            self.entry.configure(fg=self._placeholder_fg)

    def get_query(self) -> str:
        if self._showing_ph:
            return ""
        return self._var.get().strip()

    def set_colors(self, *, fill: str, border: str, fg: str, canvas_bg: str,
                   placeholder_fg: str | None = None) -> None:
        self._fill, self._border, self._fg, self._canvas_bg = fill, border, fg, canvas_bg
        if placeholder_fg:
            self._placeholder_fg = placeholder_fg
        self.configure(bg=canvas_bg)
        self._cv.configure(bg=canvas_bg)
        active_fg = self._placeholder_fg if self._showing_ph else fg
        self.entry.configure(bg=fill, fg=active_fg, insertbackground=fg,
                             disabledbackground=fill, disabledforeground=fg)
        self._redraw()

    def _redraw(self, _event=None) -> None:
        w = max(self._cv.winfo_width(), self._bw, 2)
        h = max(self._cv.winfo_height(), self._bh, 2)
        self._cv.delete("shape")
        _round_rect(self._cv, 1, 1, w - 2, h - 2, self._radius,
                    fill=self._fill, outline=self._border, width=1, tags="shape")
        self._cv.coords(self._win, 16, h // 2)
        self._cv.itemconfigure(self._win, width=max(w - 32, 40), height=h - 12)
        self._cv.tag_lower("shape")


class TextSelectList(tk.Frame):
    """THEME / CATEGORY list — single-line labels; scrollbar only when needed."""

    def __init__(self, master, *, on_select=None, fonts: dict | None = None, **kw):
        super().__init__(master, highlightthickness=0, bd=0, **kw)
        self.on_select = on_select
        self._fonts = fonts or {"list": ("Segoe UI", 10)}
        self._items: list[str] = []
        self._rows: list[tk.Frame] = []
        self._selected = -1
        self._bg = "#ffffff"
        self._fg = "#0f172a"
        self._sel_bg = "#bfdbfe"
        self._hover_bg = "#e2e8f0"
        self._sel_fg: str | None = None

        self._canvas = tk.Canvas(self, highlightthickness=0, bd=0, bg=self._bg)
        self._sb = tk.Scrollbar(self, orient="vertical", command=self._canvas.yview,
                                highlightthickness=0, bd=0)
        self._inner = tk.Frame(self._canvas, bg=self._bg, highlightthickness=0, bd=0)
        self._win = self._canvas.create_window((0, 0), window=self._inner, anchor="nw")
        self._canvas.configure(yscrollcommand=self._on_yscroll)

        self._canvas.grid(row=0, column=0, sticky="nsew")
        # Scrollbar starts hidden — shown only when content overflows
        self.rowconfigure(0, weight=1)
        self.columnconfigure(0, weight=1)

        self._inner.bind("<Configure>", self._on_inner_configure)
        self._canvas.bind("<Configure>", self._on_canvas_configure)
        self._canvas.bind("<Enter>", lambda _e: self._canvas.bind_all("<MouseWheel>", self._on_wheel))
        self._canvas.bind("<Leave>", lambda _e: self._canvas.unbind_all("<MouseWheel>"))

    def _on_yscroll(self, first: str, last: str) -> None:
        if float(first) <= 0.0 and float(last) >= 1.0:
            self._sb.grid_remove()
            self._canvas.yview_moveto(0)
        else:
            self._sb.grid(row=0, column=1, sticky="ns")
            self._sb.set(first, last)

    def _on_inner_configure(self, _e=None) -> None:
        self._canvas.configure(scrollregion=self._canvas.bbox("all"))

    def _on_canvas_configure(self, event) -> None:
        self._canvas.itemconfigure(self._win, width=event.width)

    def _on_wheel(self, event) -> None:
        # Only scroll when overflow exists
        first, last = self._canvas.yview()
        if float(first) <= 0.0 and float(last) >= 1.0:
            return
        self._canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")

    def set_colors(self, *, bg: str, fg: str, sel_bg: str, hover_bg: str,
                   sb_bg: str, sb_trough: str, sb_active: str, sel_fg: str | None = None) -> None:
        self._bg, self._fg, self._sel_bg, self._hover_bg = bg, fg, sel_bg, hover_bg
        self._sel_fg = sel_fg
        self.configure(bg=bg)
        self._canvas.configure(bg=bg)
        self._inner.configure(bg=bg)
        self._sb.configure(bg=sb_bg, troughcolor=sb_trough, activebackground=sb_active,
                           highlightbackground=bg)
        sel, items = self._selected, list(self._items)
        if items:
            self.set_items(items)
            if 0 <= sel < len(items):
                self._select(sel, notify=False)

    def clear(self) -> None:
        for row in self._rows:
            row.destroy()
        self._rows.clear()
        self._items.clear()
        self._selected = -1

    def set_items(self, items: list[str]) -> None:
        self.clear()
        self._items = list(items)
        for idx, text in enumerate(self._items):
            self._rows.append(self._make_row(idx, text))
        self._inner.update_idletasks()
        self._canvas.configure(scrollregion=self._canvas.bbox("all"))

    def _make_row(self, idx: int, text: str) -> tk.Frame:
        row = tk.Frame(self._inner, bg=self._bg, highlightthickness=0, bd=0, cursor="hand2")
        row.pack(fill="x", pady=0, padx=1)
        # wraplength=0 → single line (wider Theme/Category cols keep names on one row)
        lbl = tk.Label(row, text=text, fg=self._fg, bg=self._bg, font=self._fonts.get("list"),
                       anchor="w", justify="left", wraplength=0)
        lbl.pack(fill="x", expand=True, padx=8, pady=5)
        row._txt = lbl  # type: ignore[attr-defined]

        for w in (row, lbl):
            w.bind("<Button-1>", lambda _e, i=idx: self._select(i, notify=True))
            w.bind("<Enter>", lambda _e, i=idx: self._hover(i, True))
            w.bind("<Leave>", lambda _e, i=idx: self._hover(i, False))
        return row

    def _paint(self, idx: int, bg: str) -> None:
        if idx < 0 or idx >= len(self._rows):
            return
        row = self._rows[idx]
        fg = self._sel_fg if (bg == self._sel_bg and self._sel_fg) else self._fg
        row.configure(bg=bg)
        row._txt.configure(bg=bg, fg=fg)  # type: ignore[attr-defined]

    def _hover(self, idx: int, entering: bool) -> None:
        if idx == self._selected:
            return
        self._paint(idx, self._hover_bg if entering else self._bg)

    def _select(self, idx: int, *, notify: bool) -> None:
        if idx < 0 or idx >= len(self._items):
            return
        prev = self._selected
        self._selected = idx
        if prev >= 0:
            self._paint(prev, self._bg)
        self._paint(idx, self._sel_bg)
        if notify and self.on_select:
            self.on_select()

    def curselection(self) -> tuple[int, ...]:
        return (self._selected,) if self._selected >= 0 else ()

    def get(self, index: int) -> str:
        return self._items[index]

    def size(self) -> int:
        return len(self._items)

    def selection_set(self, index: int) -> None:
        self._select(index, notify=False)

    def delete(self, *_args) -> None:
        self.clear()


class RiskScriptList(tk.Frame):
    """SCRIPTS column: colored risk dots, single-line labels, V+H scrollbars."""

    def __init__(self, master, *, on_select=None, fonts: dict | None = None,
                 risk_colors: dict | None = None, **kw):
        super().__init__(master, highlightthickness=0, bd=0, **kw)
        self.on_select = on_select
        self._fonts = fonts or {"list": ("Segoe UI", 10), "dot": ("Segoe UI", 11)}
        self._risk_colors = risk_colors or RISK_DOT
        self._items: list[dict] = []
        self._rows: list[tk.Frame] = []
        self._selected = -1
        self._bg = "#ffffff"
        self._fg = "#0f172a"
        self._sel_bg = "#bfdbfe"
        self._hover_bg = "#e2e8f0"
        self._sel_fg: str | None = None
        self._info_fg = "#63b3ed"

        self._canvas = tk.Canvas(self, highlightthickness=0, bd=0, bg=self._bg)
        self._sb_y = tk.Scrollbar(self, orient="vertical", command=self._canvas.yview,
                                  highlightthickness=0, bd=0)
        self._sb_x = tk.Scrollbar(self, orient="horizontal", command=self._canvas.xview,
                                  highlightthickness=0, bd=0)
        self._inner = tk.Frame(self._canvas, bg=self._bg, highlightthickness=0, bd=0)
        self._win = self._canvas.create_window((0, 0), window=self._inner, anchor="nw")
        self._canvas.configure(yscrollcommand=self._on_yscroll, xscrollcommand=self._on_xscroll)

        # Canvas fills; scrollbars appear only when content overflows
        self._canvas.grid(row=0, column=0, sticky="nsew")
        self.rowconfigure(0, weight=1)
        self.columnconfigure(0, weight=1)

        self._inner.bind("<Configure>", self._on_inner_configure)
        self._canvas.bind("<Configure>", self._on_canvas_configure)
        self._canvas.bind("<Enter>", lambda _e: self._bind_mousewheel(True))
        self._canvas.bind("<Leave>", lambda _e: self._bind_mousewheel(False))

    def _on_yscroll(self, first: str, last: str) -> None:
        if float(first) <= 0.0 and float(last) >= 1.0:
            self._sb_y.grid_remove()
            self._canvas.yview_moveto(0)
        else:
            self._sb_y.grid(row=0, column=1, sticky="ns")
            self._sb_y.set(first, last)

    def _on_xscroll(self, first: str, last: str) -> None:
        if float(first) <= 0.0 and float(last) >= 1.0:
            self._sb_x.grid_remove()
            self._canvas.xview_moveto(0)
        else:
            self._sb_x.grid(row=1, column=0, sticky="ew")
            self._sb_x.set(first, last)

    def _bind_mousewheel(self, active: bool) -> None:
        if active:
            self._canvas.bind_all("<MouseWheel>", self._on_mousewheel)
            self._canvas.bind_all("<Shift-MouseWheel>", self._on_shift_mousewheel)
        else:
            self._canvas.unbind_all("<MouseWheel>")
            self._canvas.unbind_all("<Shift-MouseWheel>")

    def _on_mousewheel(self, event) -> None:
        first, last = self._canvas.yview()
        if float(first) <= 0.0 and float(last) >= 1.0:
            return
        self._canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")

    def _on_shift_mousewheel(self, event) -> None:
        first, last = self._canvas.xview()
        if float(first) <= 0.0 and float(last) >= 1.0:
            return
        self._canvas.xview_scroll(int(-1 * (event.delta / 120)), "units")

    def _on_inner_configure(self, _e=None) -> None:
        self._sync_scrollregion()

    def _on_canvas_configure(self, _event=None) -> None:
        # Keep inner at least as wide as the viewport; grow for long single-line labels
        self._sync_scrollregion()

    def _sync_scrollregion(self) -> None:
        self._inner.update_idletasks()
        req_w = max(self._inner.winfo_reqwidth(), max(self._canvas.winfo_width(), 1))
        self._canvas.itemconfigure(self._win, width=req_w)
        self._inner.update_idletasks()
        self._canvas.configure(scrollregion=self._canvas.bbox("all"))

    def set_colors(self, *, bg: str, fg: str, sel_bg: str, hover_bg: str,
                   sb_bg: str, sb_trough: str, sb_active: str, sel_fg: str | None = None,
                   info_fg: str | None = None) -> None:
        self._bg, self._fg = bg, fg
        self._sel_bg, self._hover_bg = sel_bg, hover_bg
        self._sel_fg = sel_fg
        if info_fg:
            self._info_fg = info_fg
        self.configure(bg=bg)
        self._canvas.configure(bg=bg)
        self._inner.configure(bg=bg)
        for sb in (self._sb_y, self._sb_x):
            sb.configure(bg=sb_bg, troughcolor=sb_trough, activebackground=sb_active,
                         highlightbackground=bg)
        sel = self._selected
        items = list(self._items)
        if items:
            self.set_items(items)
            if 0 <= sel < len(items):
                self._select(sel, notify=False)

    def clear(self) -> None:
        for row in self._rows:
            row.destroy()
        self._rows.clear()
        self._items.clear()
        self._selected = -1
        self._canvas.configure(scrollregion=(0, 0, 0, 0))

    def set_items(self, scripts: list[dict]) -> None:
        self.clear()
        self._items = list(scripts)
        for idx, s in enumerate(self._items):
            self._rows.append(self._make_row(idx, s))
        self._inner.update_idletasks()
        self._sync_scrollregion()

    def _make_row(self, idx: int, s: dict) -> tk.Frame:
        row = tk.Frame(self._inner, bg=self._bg, highlightthickness=0, bd=0, cursor="hand2")
        row.pack(fill="x", pady=0, padx=1)

        risk = s.get("risk", "Low")
        dot_color = self._risk_colors.get(risk, self._risk_colors.get("Low", "#48bb78"))
        label = s.get("label") or s.get("name") or ""
        info_fg = self._info_fg or "#63b3ed"

        # Info icon (left of risk dot) — click for full technician briefing
        info = tk.Label(row, text="ℹ", fg=info_fg, bg=self._bg,
                        font=self._fonts.get("info", ("Segoe UI", 11, "bold")),
                        width=2, anchor="center", cursor="hand2")
        info.pack(side="left", padx=(2, 0), pady=4)

        # Colored risk ellipse (same hex as MASTER-MENU.ps1 Get-RiskBrush)
        dot = tk.Label(row, text="●", fg=dot_color, bg=self._bg, font=self._fonts.get("dot", ("Segoe UI", 11)),
                       width=2, anchor="center")
        dot.pack(side="left", padx=(0, 6), pady=4)
        # Single line — horizontal scrollbar reveals the rest (like WPF ListBox)
        txt = tk.Label(row, text=label, fg=self._fg, bg=self._bg, font=self._fonts.get("list", ("Segoe UI", 10)),
                       anchor="w", justify="left", wraplength=0)
        txt.pack(side="left", pady=4, padx=(0, 8))

        row._info = info  # type: ignore[attr-defined]
        row._dot = dot  # type: ignore[attr-defined]
        row._txt = txt  # type: ignore[attr-defined]

        tip = s.get("info_tip") or s.get("care") or label
        self._attach_tooltip(info, tip)

        def on_info(_e=None, i=idx, script=s):
            self._select(i, notify=True)
            body = script.get("info_text") or script.get("info_tip") or script.get("care") or ""
            # Resolve palette from parent App when available
            app = self.winfo_toplevel()
            kwargs = {}
            if hasattr(app, "palettes") and hasattr(app, "ui_mode"):
                p = app.palettes[app.ui_mode]
                kwargs = dict(
                    bg=p["WindowBg"], panel=p["PanelBg"], fg=p["TextPrimary"],
                    title_fg=p["TextTitle"], btn_bg=p["BtnRunBg"], btn_fg=p["BtnRunFg"],
                )
            show_script_info_dialog(app, body, **kwargs)
            return "break"

        info.bind("<Button-1>", on_info)

        def bind_all(widget: tk.Misc) -> None:
            widget.bind("<Button-1>", lambda _e, i=idx: self._select(i, notify=True))
            widget.bind("<Enter>", lambda _e, i=idx: self._hover(i, True))
            widget.bind("<Leave>", lambda _e, i=idx: self._hover(i, False))

        for w in (row, dot, txt):
            bind_all(w)
        info.bind("<Enter>", lambda _e, i=idx: self._hover(i, True))
        info.bind("<Leave>", lambda _e, i=idx: self._hover(i, False))
        return row

    def _attach_tooltip(self, widget: tk.Misc, text: str) -> None:
        tip: dict[str, object] = {"win": None, "after": None}

        def hide(_e=None) -> None:
            aid = tip.get("after")
            if aid is not None:
                try:
                    widget.after_cancel(aid)  # type: ignore[arg-type]
                except Exception:
                    pass
                tip["after"] = None
            w = tip.get("win")
            tip["win"] = None
            if w is not None:
                try:
                    w.destroy()  # type: ignore[union-attr]
                except tk.TclError:
                    pass

        def show_now() -> None:
            if tip["win"] is not None:
                return
            tw = tk.Toplevel(widget)
            tw.wm_overrideredirect(True)
            try:
                tw.attributes("-topmost", True)
            except tk.TclError:
                pass
            x = widget.winfo_rootx() + 18
            y = widget.winfo_rooty() + widget.winfo_height() + 4
            tw.geometry(f"+{x}+{y}")
            tk.Label(
                tw, text=text, justify="left", relief="solid", borderwidth=1,
                bg="#1a202c", fg="#e2e8f0", font=self._fonts.get("body_sm", ("Segoe UI", 9)),
                padx=10, pady=8, wraplength=420,
            ).pack()
            tip["win"] = tw

        def schedule(_e=None) -> None:
            hide()
            tip["after"] = widget.after(400, show_now)

        widget.bind("<Enter>", schedule, add="+")
        widget.bind("<Leave>", hide, add="+")

    def _paint_row(self, idx: int, bg: str) -> None:
        if idx < 0 or idx >= len(self._rows):
            return
        row = self._rows[idx]
        row.configure(bg=bg)
        row._info.configure(bg=bg, fg=self._info_fg)  # type: ignore[attr-defined]
        row._dot.configure(bg=bg)  # type: ignore[attr-defined]
        fg = self._fg
        if bg == self._sel_bg and self._sel_fg:
            fg = self._sel_fg
        row._txt.configure(bg=bg, fg=fg)  # type: ignore[attr-defined]

    def _hover(self, idx: int, entering: bool) -> None:
        if idx == self._selected:
            return
        self._paint_row(idx, self._hover_bg if entering else self._bg)

    def _select(self, idx: int, *, notify: bool) -> None:
        if idx < 0 or idx >= len(self._items):
            return
        prev = self._selected
        self._selected = idx
        if prev >= 0:
            self._paint_row(prev, self._bg)
        self._paint_row(idx, self._sel_bg)
        if notify and self.on_select:
            self.on_select()

    def curselection(self) -> tuple[int, ...]:
        return (self._selected,) if self._selected >= 0 else ()

    def delete(self, *_args) -> None:
        self.clear()


# ── main app ────────────────────────────────────────────────────────────────

class App(tk.Tk):
    def __init__(self, catalog: list[dict], *, style: str = "auto"):
        super().__init__()
        self.catalog = catalog
        self.win_n, self.mac_n, self.cat_n = catalog_stats(catalog)
        self.ui_style = resolve_ui_style(None if style == "auto" else style)
        self.palettes = ui_palettes(self.ui_style)
        self.F = ui_fonts(self.ui_style)
        self.M = ui_metrics(self.ui_style)
        style_label = "macOS" if self.ui_style == "macos" else "Windows"
        self.title(f"{BRAND} - Unified Launcher v{PRODUCT_VERSION}")
        self.minsize(1100, 680)
        center_on_screen(self, 1360, 780)
        self.platform = "macOS" if sys.platform == "darwin" else "Windows"
        self.role = "SysAdmin"
        self.filtered_cats: list[dict] = []
        self.selected_cat: dict | None = None
        self.ui_mode = self._load_theme()  # default Light (same as MASTER-MENU.ps1)
        self._frames: list[tk.Misc] = []

        pad = self.M["pad"]
        self.root = tk.Frame(self, bd=0, highlightthickness=0)
        self.root.pack(fill="both", expand=True, padx=pad, pady=pad)
        self.root.rowconfigure(3, weight=1, minsize=200)
        self.root.columnconfigure(0, weight=1)

        self._build_header()
        self._build_platform()
        self._build_role()
        self._build_lists()
        self._build_buttons()
        self._build_status()
        self._build_footer()

        self.apply_theme()
        self.on_platform()
        self.log_msg(
            f"GUI ready v{PRODUCT_VERSION} · UI style: {style_label}. "
            f"Catalog: {self.win_n} Windows + {self.mac_n} macOS scripts in {self.cat_n} categories. "
            f"Theme: {self.ui_mode}."
        )
        # Re-center after layout so every launch lands on the same mid-screen spot
        self.after_idle(lambda: center_on_screen(self, 1360, 780))

    def _track(self, w: tk.Misc) -> tk.Misc:
        self._frames.append(w)
        return w

    def _build_header(self) -> None:
        hdr = self._track(tk.Frame(self.root, bd=0, highlightthickness=0))
        hdr.grid(row=0, column=0, sticky="ew", pady=(0, 10))
        hdr.columnconfigure(1, weight=1)
        self.hdr = hdr

        left = self._track(tk.Frame(hdr, bd=0, highlightthickness=0))
        left.grid(row=0, column=0, sticky="w")
        self.hdr_left = left
        self.lbl_title = tk.Label(left, text=BRAND, font=self.F["title"], anchor="w")
        self.lbl_title.pack(anchor="w")
        self.lbl_sub = tk.Label(left, text=TAGLINE, font=self.F["subtitle"], anchor="w")
        self.lbl_sub.pack(anchor="w", pady=(2, 0))

        # Keep search + theme together so the theme button never clips
        right = self._track(tk.Frame(hdr, bd=0, highlightthickness=0))
        right.grid(row=0, column=2, sticky="e")
        self.search_wrap = right

        self.lbl_search = tk.Label(right, text="Search Scripts", font=self.F["search_lbl"])
        self.search_var = tk.StringVar()
        # Match PS1: always show Search Scripts label + box (no macOS-only placeholder mode gap)
        ph = ""
        self.search_box = RoundedSearch(
            right, textvariable=self.search_var, radius=self.M["search_radius"],
            width=self.M["search_w"], height=self.M["btn_h"], placeholder=ph,
        )
        self.search_box.entry.configure(font=self.F["list"])
        self.lbl_search.pack(side="left", padx=(0, 10))
        self.search_box.pack(side="left", padx=(0, 12))
        self.search_var.trace_add("write", lambda *_: self.refresh_themes())

        self.btn_theme = RoundedButton(
            right, text="Dark Mode", command=self.toggle_theme, radius=self.M["pill_radius"],
            width=self.M["theme_btn_w"], height=self.M["btn_h"], font=self.F["btn"],
        )
        self.btn_theme.pack(side="left")

    def _build_platform(self) -> None:
        self.panel_plat = RoundedCard(
            self.root, radius=self.M["card_radius"],
            padx=self.M["plat_padx"], pady=self.M["plat_pady"],
        )
        self.panel_plat.grid(row=1, column=0, sticky="ew", pady=(0, 8))
        inner = self._track(self.panel_plat.inner)
        self.lbl_plat = tk.Label(inner, text="PLATFORM", font=self.F["section"], anchor="w")
        self.lbl_plat.pack(anchor="w", pady=(0, 6))
        row = self._track(tk.Frame(inner, bd=0, highlightthickness=0))
        row.pack(anchor="w", fill="x")
        self.plat_var = tk.StringVar(value=self.platform)
        self.rb_win = tk.Radiobutton(row, text="Windows", variable=self.plat_var, value="Windows",
                                     command=self.on_platform, font=self.F["body"], anchor="w")
        self.rb_mac = tk.Radiobutton(row, text="macOS", variable=self.plat_var, value="macOS",
                                     command=self.on_platform, font=self.F["body"], anchor="w")
        self.rb_win.pack(side="left", padx=(0, 18))
        self.rb_mac.pack(side="left", padx=(0, 18))
        self.hint = tk.Label(row, text="", font=self.F["body_sm"], anchor="w")
        self.hint.pack(side="left")

    def _build_role(self) -> None:
        self.panel_role = RoundedCard(
            self.root, radius=self.M["card_radius"],
            padx=self.M["plat_padx"], pady=self.M["plat_pady"],
        )
        self.panel_role.grid(row=2, column=0, sticky="ew", pady=(0, 8))
        inner = self._track(self.panel_role.inner)
        self.lbl_role = tk.Label(inner, text="ROLE", font=self.F["section"], anchor="w")
        self.lbl_role.pack(anchor="w", pady=(0, 6))
        row = self._track(tk.Frame(inner, bd=0, highlightthickness=0))
        row.pack(anchor="w")
        self.role_var = tk.StringVar(value=self.role)
        self.rb_sa = tk.Radiobutton(row, text="System Administrator", variable=self.role_var,
                                    value="SysAdmin", command=self.on_role, font=self.F["body"])
        self.rb_it = tk.Radiobutton(row, text="IT Support", variable=self.role_var,
                                    value="ITSupport", command=self.on_role, font=self.F["body"])
        self.rb_sa.pack(side="left", padx=(0, 18))
        self.rb_it.pack(side="left")

    def _build_lists(self) -> None:
        mid = self._track(tk.Frame(self.root, bd=0, highlightthickness=0))
        mid.grid(row=3, column=0, sticky="nsew")
        tw, cw = self.M["theme_col"], self.M["cat_col"]
        # Fixed Theme/Category widths (no stretch) → no empty strip on the right
        mid.columnconfigure(0, weight=0, minsize=tw)
        mid.columnconfigure(1, weight=0, minsize=10)
        mid.columnconfigure(2, weight=0, minsize=cw)
        mid.columnconfigure(3, weight=0, minsize=10)
        mid.columnconfigure(4, weight=1, minsize=320)
        mid.rowconfigure(0, weight=1)
        self.mid = mid

        cp, cq = self.M["card_padx"], self.M["card_pady"]
        self.panel_theme = RoundedCard(mid, radius=self.M["card_radius"], padx=cp, pady=cq)
        self.panel_theme.configure(width=tw)
        self.panel_theme.pack_propagate(False)  # children use pack; lock Theme col width
        self.panel_theme.grid(row=0, column=0, sticky="nsew")
        self.panel_cat = RoundedCard(mid, radius=self.M["card_radius"], padx=cp, pady=cq)
        self.panel_cat.configure(width=cw)
        self.panel_cat.pack_propagate(False)  # lock Category col width
        self.panel_cat.grid(row=0, column=2, sticky="nsew")
        self.panel_scripts = RoundedCard(mid, radius=self.M["card_radius"], padx=cp, pady=cq)
        self.panel_scripts.grid(row=0, column=4, sticky="nsew")

        def list_block(parent_inner: tk.Frame, title: str, with_legend: bool = False):
            box = self._track(tk.Frame(parent_inner, bd=0, highlightthickness=0))
            box.pack(fill="both", expand=True)
            head = self._track(tk.Frame(box, bd=0, highlightthickness=0))
            head.pack(fill="x", pady=(0, 8))
            lbl = tk.Label(head, text=title, font=self.F["section"], anchor="w")
            lbl.pack(side="left", padx=(4, 0))
            legends = []
            if with_legend:
                legend_colors = (
                    (("#30d158", "safe"), ("#ffd60a", "changes config"), ("#ff453a", "high impact"))
                    if self.ui_style == "macos"
                    else (("#48bb78", "safe"), ("#ecc94b", "changes config"), ("#fc8181", "high impact"))
                )
                for color, text in legend_colors:
                    dot = tk.Label(head, text="●", fg=color, font=self.F["body_sm"])
                    dot.pack(side="left", padx=(10, 2))
                    t = tk.Label(head, text=text, font=self.F["body_sm"])
                    t.pack(side="left", padx=(0, 8))
                    legends.extend([dot, t])
            list_row = self._track(tk.Frame(box, bd=0, highlightthickness=0))
            list_row.pack(fill="both", expand=True)
            return box, head, lbl, list_row, legends

        _, _, self.lbl_theme, theme_row, _ = list_block(self.panel_theme.inner, "THEME")
        _, _, self.lbl_cat, cat_row, _ = list_block(self.panel_cat.inner, "CATEGORY")
        _, _, self.lbl_scripts, script_row, self.legend_labels = list_block(
            self.panel_scripts.inner, "SCRIPTS", with_legend=True
        )

        self.theme_list = TextSelectList(theme_row, on_select=self.refresh_categories, fonts=self.F)
        self.theme_list.pack(fill="both", expand=True)
        self.theme_sb = self.theme_list._sb

        self.cat_list = TextSelectList(cat_row, on_select=self.refresh_scripts, fonts=self.F)
        self.cat_list.pack(fill="both", expand=True)
        self.cat_sb = self.cat_list._sb

        self.script_list = RiskScriptList(
            script_row, on_select=self.on_script_select, fonts=self.F,
            risk_colors=RISK_DOT_MACOS if self.ui_style == "macos" else RISK_DOT,
        )
        self.script_list.pack(fill="both", expand=True)
        self.script_sb = self.script_list._sb_y
        self.script_sb_x = self.script_list._sb_x

    def _build_buttons(self) -> None:
        bar = self._track(tk.Frame(self.root, bd=0, highlightthickness=0))
        bar.grid(row=4, column=0, sticky="e", pady=(10, 8))
        self.btn_bar = bar
        r = self.M["btn_radius"]
        self.btn_folder = RoundedButton(bar, text="Open Folder", command=self.open_folder,
                                        width=118, height=36, radius=r, font=self.F["btn"])
        # Dual action: Windows platform → ISE/Editor; macOS platform → Install PowerShell
        self.btn_ise = RoundedButton(bar, text="Open in ISE", command=self.on_ise_or_install,
                                     width=168, height=36, radius=r, font=self.F["btn"])
        self.btn_dry = RoundedButton(bar, text="Dry Run (Preview)", command=self.dry_run_script,
                                     width=148, height=36, radius=r, font=self.F["btn"])
        self.btn_run = RoundedButton(bar, text="Run Elevated", command=self.run_script,
                                     width=160, height=36, radius=r, font=self.F["btn_bold"])
        self.btn_folder.pack(side="left", padx=(0, 8))
        self.btn_ise.pack(side="left", padx=(0, 8))
        self.btn_dry.pack(side="left", padx=(0, 8))
        self.btn_run.pack(side="left")

    def _build_status(self) -> None:
        self.panel_status = RoundedCard(
            self.root, radius=self.M["card_radius"],
            padx=self.M["status_padx"], pady=self.M["status_pady"],
        )
        self.panel_status.grid(row=5, column=0, sticky="ew")
        self.panel_status.configure(height=self.M["status_h"])
        self.panel_status.pack_propagate(False)
        inner = self._track(self.panel_status.inner)
        self.lbl_status = tk.Label(inner, text="STATUS", font=self.F["section"], anchor="w")
        self.lbl_status.pack(anchor="w", pady=(0, 6))
        out_outer = RoundedCard(inner, radius=self.M["output_radius"], padx=6, pady=6)
        out_outer.pack(fill="both", expand=True)
        self.out_card = out_outer
        self.log = tk.Text(out_outer.inner, height=4, relief="flat", bd=0, highlightthickness=0,
                           font=self.F["mono"], wrap="word")
        self.log.pack(fill="both", expand=True)

    def _build_footer(self) -> None:
        year = datetime.now().year
        self.lbl_copy = tk.Label(
            self.root, text=f"© {year} Allester Padovani. All rights reserved.",
            font=self.F["body_sm"], anchor="center",
        )
        self.lbl_copy.grid(row=6, column=0, sticky="ew", pady=(8, 0))

    # --- theme persistence (same file as MASTER-MENU.ps1) ---
    def _load_theme(self) -> str:
        for path in (THEME_PREF, THEME_PREF_LEGACY):
            try:
                if path.is_file():
                    v = path.read_text(encoding="ascii").strip()
                    if v in ("Dark", "Light"):
                        return v
            except OSError:
                pass
        return "Light"  # match MASTER-MENU.ps1 default

    def _save_theme(self) -> None:
        try:
            THEME_PREF.write_text(self.ui_mode, encoding="ascii")
        except OSError:
            pass

    def toggle_theme(self) -> None:
        self.ui_mode = "Light" if self.ui_mode == "Dark" else "Dark"
        self.apply_theme()
        self.log_msg(f"Color theme: {self.ui_mode}")

    def apply_theme(self) -> None:
        p = self.palettes[self.ui_mode]
        win_bg, panel = p["WindowBg"], p["PanelBg"]

        self.configure(bg=win_bg)
        self.root.configure(bg=win_bg)
        for fr in self._frames:
            try:
                bg = panel if self._is_under_panel(fr) else win_bg
                fr.configure(bg=bg)
            except tk.TclError:
                pass

        for card in (self.panel_plat, self.panel_role, self.panel_theme, self.panel_cat,
                     self.panel_scripts, self.panel_status):
            card.set_colors(fill=panel, border=p["PanelBorder"], canvas_bg=win_bg)

        self.out_card.set_colors(fill=p["OutputBg"], border=p["PanelBorder"], canvas_bg=panel)

        # Header / footer chrome
        for w in (self.hdr, self.hdr_left, self.search_wrap, self.mid, self.btn_bar):
            w.configure(bg=win_bg)
        self.lbl_title.configure(bg=win_bg, fg=p["TextTitle"])
        self.lbl_sub.configure(bg=win_bg, fg=p["TextMuted"])
        self.lbl_search.configure(bg=win_bg, fg=p["TextSecondary"])
        self.lbl_copy.configure(bg=win_bg, fg=p["TextMuted"])

        self.lbl_plat.configure(bg=panel, fg=p["TextSection"])
        self.lbl_role.configure(bg=panel, fg=p["TextSection"])
        # macOS: section labels use system blue; Windows: amber accent on list headers
        list_hdr = p["TextSection"] if self.ui_style == "macos" else p["TextAccent"]
        self.lbl_theme.configure(bg=panel, fg=list_hdr)
        self.lbl_cat.configure(bg=panel, fg=list_hdr)
        self.lbl_scripts.configure(bg=panel, fg=list_hdr)
        self.lbl_status.configure(bg=panel, fg=p["TextSection"])
        self.hint.configure(bg=panel)

        for rb in (self.rb_win, self.rb_mac, self.rb_sa, self.rb_it):
            rb.configure(
                bg=panel, fg=p["TextPrimary"],
                activebackground=panel, activeforeground=p["TextPrimary"],
                selectcolor=p["RadioSelect"],
                highlightthickness=0, highlightbackground=panel,
                disabledforeground=p["TextMuted"],
            )

        # List selection: macOS uses system blue → white text
        sel_fg = "#ffffff" if self.ui_style == "macos" else p["TextPrimary"]
        for lb in (self.theme_list, self.cat_list):
            lb.set_colors(
                bg=panel, fg=p["TextPrimary"],
                sel_bg=p["ListSelected"], hover_bg=p["ListHover"],
                sb_bg=p["BtnSecondaryBg"], sb_trough=panel, sb_active=p["BtnSecondaryHover"],
                sel_fg=sel_fg if self.ui_style == "macos" else None,
            )
        self.script_list.set_colors(
            bg=panel, fg=p["TextPrimary"],
            sel_bg=p["ListSelected"], hover_bg=p["ListHover"],
            sb_bg=p["BtnSecondaryBg"], sb_trough=panel, sb_active=p["BtnSecondaryHover"],
            sel_fg=("#ffffff" if self.ui_style == "macos" else None),
            info_fg=p["TextAccent"] if self.ui_style != "macos" else p["TextTitle"],
        )

        for leg in self.legend_labels:
            if leg.cget("text") == "●":
                leg.configure(bg=panel)
            else:
                leg.configure(bg=panel, fg=p["TextSecondary"])

        # Search: forced InputFg so light mode text is always visible
        self.search_box.set_colors(
            fill=p["InputBg"], border=p["InputBorder"], fg=p["InputFg"], canvas_bg=win_bg,
            placeholder_fg=p["TextMuted"],
        )

        self.log.configure(
            bg=p["OutputBg"], fg=p["OutputFg"], insertbackground=p["OutputFg"],
            selectbackground=p["ListSelected"],
            selectforeground=sel_fg,
        )

        # Theme toggle — full label, never clipped
        self.btn_theme.set_style(
            fill=p["ThemeBtnBg"], fg=p["ThemeBtnFg"], border=p["ThemeBtnBorder"],
            hover=p["ThemeBtnHover"], canvas_bg=win_bg,
            text=("Light Mode" if self.ui_mode == "Dark" else "Dark Mode"),
            font=self.F["btn"],
        )

        self.btn_folder.set_style(
            fill=p["BtnSecondaryBg"], fg=p["BtnSecondaryFg"], border=p["PanelBorder"],
            hover=p["BtnSecondaryHover"], canvas_bg=win_bg, text="Open Folder",
            font=self.F["btn"],
        )
        self.btn_ise.set_style(
            fill=p["BtnSecondaryBg"], fg=p["BtnSecondaryFg"], border=p["PanelBorder"],
            hover=p["BtnSecondaryHover"], canvas_bg=win_bg,
            text=self._ise_button_label(),
            font=self.F["btn"],
        )
        self.btn_dry.set_style(
            fill=p["BtnDryRunBg"], fg=p["BtnDryRunFg"], border=p["BtnDryRunFg"],
            hover=p["BtnDryRunHover"], canvas_bg=win_bg, text="Dry Run (Preview)",
            font=self.F["btn"],
        )
        self.btn_run.set_style(
            fill=p["BtnRunBg"], fg=p["BtnRunFg"], border=p["BtnRunBorder"],
            hover=p["BtnRunHover"], canvas_bg=win_bg, text="Run Elevated",
            font=self.F["btn_bold"],
        )

        self._save_theme()
        self.update_run_buttons()

    def _is_under_panel(self, widget: tk.Misc) -> bool:
        panels = {
            self.panel_plat.inner, self.panel_role.inner, self.panel_theme.inner,
            self.panel_cat.inner, self.panel_scripts.inner, self.panel_status.inner,
            self.out_card.inner,
        }
        w: tk.Misc | None = widget
        while w is not None:
            if w in panels:
                return True
            w = getattr(w, "master", None)
        return False

    # --- catalog UI ---
    def log_msg(self, msg: str) -> None:
        self.log.insert("end", f"[{datetime.now().strftime('%H:%M:%S')}] {msg}\n")
        self.log.see("end")

    def can_run_native(self) -> bool:
        host = platform.system()
        return (self.platform == "macOS" and host == "Darwin") or (self.platform == "Windows" and host == "Windows")

    def _run_unavailable_msg(self) -> None:
        host = platform.system()
        if self.platform == "macOS" and host != "Darwin":
            messagebox.showinfo(
                "Run unavailable on this PC",
                "PLATFORM is set to macOS, but you are on Windows.\n\n"
                "• Switch PLATFORM → Windows to Dry Run / Run Elevated here\n"
                "• Or open this toolkit on a Mac to run macOS scripts",
            )
            self.log_msg("Run blocked: macOS scripts cannot execute on Windows. Switch PLATFORM to Windows.")
            return
        if self.platform == "Windows" and host != "Windows":
            messagebox.showinfo(
                "Run unavailable on this Mac",
                "PLATFORM is set to Windows, but you are on macOS.\n\n"
                "Switch PLATFORM → macOS to run scripts on this Mac.",
            )
            self.log_msg("Run blocked: Windows scripts cannot execute on this Mac.")
            return
        messagebox.showinfo("Run unavailable", "This script cannot run on the current host OS.")

    def _ise_button_label(self) -> str:
        if self.platform == "macOS":
            return "Install PowerShell"
        if platform.system() == "Windows":
            return "Open in ISE"
        return "Open in Editor"

    def on_ise_or_install(self) -> None:
        if self.platform == "macOS":
            self.install_powershell_macos()
        else:
            self.open_in_editor()

    def update_run_buttons(self) -> None:
        p = self.palettes[self.ui_mode]
        ok = self.can_run_native()
        self.btn_run.set_enabled(ok, disabled_command=self._run_unavailable_msg)
        self.btn_dry.set_enabled(ok, disabled_command=self._run_unavailable_msg)
        # Keep secondary button label in sync with PLATFORM
        self.btn_ise.set_style(
            fill=p["BtnSecondaryBg"], fg=p["BtnSecondaryFg"], border=p["PanelBorder"],
            hover=p["BtnSecondaryHover"], canvas_bg=p["WindowBg"],
            text=self._ise_button_label(), font=self.F["btn"],
        )
        if self.platform == "macOS" and platform.system() == "Darwin":
            self.hint.configure(text="macOS scripts run elevated on this Mac", fg=p["HintOk"])
        elif self.platform == "Windows" and platform.system() == "Windows":
            self.hint.configure(text="Windows scripts run elevated on this PC", fg=p["HintOk"])
        else:
            self.hint.configure(
                text="Browse only — switch PLATFORM to Windows to run here",
                fg=p["HintWarn"],
            )

    def on_platform(self) -> None:
        self.platform = self.plat_var.get()
        self.update_run_buttons()
        self.refresh_themes()

    def on_role(self) -> None:
        self.role = self.role_var.get()
        self.refresh_themes()

    def pool(self) -> list[dict]:
        q = self.search_box.get_query().lower()
        items = [c for c in self.catalog if c["platform"] == self.platform and c["role"] == self.role]
        if q:
            items = [c for c in items if q in c["display"].lower() or q in c["theme"].lower()
                     or any(q in s["name"].lower() or q in s.get("label", "").lower() for s in c["scripts"])]
        return items

    def refresh_themes(self) -> None:
        self.theme_list.clear()
        self.cat_list.clear()
        self.script_list.clear()
        pool = self.pool()
        themes = {c["theme"] for c in pool}
        items: list[str] = []
        for t in THEME_ORDER:
            if t in themes:
                items.append(f"{t}  ({sum(1 for c in pool if c['theme'] == t)})")
        for t in sorted(themes):
            if t not in THEME_ORDER:
                items.append(f"{t}  ({sum(1 for c in pool if c['theme'] == t)})")
        self.theme_list.set_items(items)
        # Subtitle always matches PS1 denser format
        role_label = "System Administrator" if self.role == "SysAdmin" else "IT Support"
        self.lbl_sub.configure(
            text=f"{self.platform} | {role_label} | {len(pool)} categories | {sum(c['count'] for c in pool)} scripts"
        )
        if self.theme_list.size():
            self.theme_list.selection_set(0)
            self.refresh_categories()

    def refresh_categories(self) -> None:
        self.cat_list.clear()
        self.script_list.clear()
        sel = self.theme_list.curselection()
        if not sel:
            return
        theme = self.theme_list.get(sel[0]).rsplit("  (", 1)[0]
        self.filtered_cats = [c for c in self.pool() if c["theme"] == theme]
        self.cat_list.set_items([f"{c['display']}  ({c['count']})" for c in self.filtered_cats])
        self.log_msg(f"Theme: {theme} ({len(self.filtered_cats)} categories)")
        if self.cat_list.size():
            self.cat_list.selection_set(0)
            self.refresh_scripts()

    def refresh_scripts(self) -> None:
        self.script_list.clear()
        sel = self.cat_list.curselection()
        if not sel:
            self.selected_cat = None
            return
        self.selected_cat = self.filtered_cats[sel[0]]
        self.script_list.set_items(self.selected_cat["scripts"])
        # Auto-select first script so Dry Run / Run work immediately
        if self.selected_cat["scripts"]:
            self.script_list._select(0, notify=True)
        self.log_msg(
            f"Category: {self.selected_cat['platform']}/{self.selected_cat['role_label']}/{self.selected_cat['display']}"
        )

    def on_script_select(self) -> None:
        s = self.selected_script()
        if not s:
            return
        self.log_msg("---")
        self.log_msg(s.get("label", s["name"]))
        self.log_msg(f"Warning: {s.get('care', '')}")
        self.log_msg(f"File: {s.get('file', Path(s['path']).name)}")

    def selected_script(self) -> dict | None:
        if not self.selected_cat:
            return None
        sel = self.script_list.curselection()
        if not sel:
            return None
        return self.selected_cat["scripts"][sel[0]]

    def confirm_risk(self, s: dict, *, dry: bool) -> bool:
        label, care, risk = s.get("label", s["path"]), s.get("care", ""), s.get("risk", "Low")
        fname = s.get("file", Path(s["path"]).name)
        mode = "PREVIEW (Dry Run)" if dry else "RUN"
        if risk == "Dangerous":
            return messagebox.askyesno(
                "Dangerous script confirmation",
                f"DANGEROUS — {mode}\n\n{label}\n\nWarning: {care}\n\nFile: {fname}\n\nAre you sure?",
                icon="warning",
            )
        if risk == "Caution":
            return messagebox.askyesno("Confirmation", f"CAUTION — {mode}\n\n{label}\n\n{care}\n\nContinue?")
        return True

    def install_powershell_macos(self) -> None:
        """Install PowerShell 7 (pwsh) on macOS via Homebrew — replaces Open in ISE for macOS."""
        if platform.system() != "Darwin":
            messagebox.showinfo(
                "Install PowerShell",
                "PowerShell for macOS must be installed on a Mac.\n\n"
                "On the Mac, open this GUI, set PLATFORM → macOS, then click Install PowerShell.\n\n"
                "Or in Terminal on the Mac:\n"
                "  brew install --cask powershell",
            )
            self.log_msg("Install PowerShell: run this on a Mac (brew install --cask powershell).")
            return

        existing = find_pwsh()
        if existing:
            ver = ""
            try:
                ver = subprocess.check_output(
                    [existing, "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"],
                    text=True, timeout=15,
                ).strip()
            except (OSError, subprocess.SubprocessError):
                pass
            msg = f"PowerShell is already installed:\n{existing}"
            if ver:
                msg += f"\nVersion: {ver}"
            msg += "\n\nOpen Terminal to use it with: pwsh"
            messagebox.showinfo("PowerShell", msg)
            self.log_msg(f"PowerShell already installed: {existing}" + (f" ({ver})" if ver else ""))
            return

        brew = shutil.which("brew")
        if not brew:
            ok = messagebox.askyesno(
                "Homebrew required",
                "Homebrew is needed to install PowerShell on macOS.\n\n"
                "Open Terminal with the Homebrew install command now?\n\n"
                "After Homebrew finishes, click Install PowerShell again.",
            )
            if not ok:
                self.log_msg("PowerShell install cancelled — Homebrew not found.")
                return
            brew_install = (
                '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; '
                'echo; read -r "?Press Enter..."'
            )
            subprocess.Popen([
                "osascript", "-e",
                f'tell application "Terminal" to do script {json.dumps(brew_install)}',
            ])
            self.log_msg("Opened Terminal to install Homebrew. Click Install PowerShell again afterward.")
            return

        ok = messagebox.askyesno(
            "Install PowerShell",
            "Install PowerShell 7 (pwsh) with Homebrew?\n\n"
            "Command:\n  brew install --cask powershell\n\n"
            "This opens Terminal and may ask for your Mac password.",
        )
        if not ok:
            self.log_msg("PowerShell install cancelled by operator.")
            return

        cmd = (
            f'echo "=== Installing PowerShell 7 (pwsh) ==="; '
            f'{json.dumps(brew)} install --cask powershell; '
            f'echo; echo "Done. Test with: pwsh -v"; '
            f'read -r "?Press Enter..."'
        )
        subprocess.Popen([
            "osascript", "-e",
            f'tell application "Terminal" to do script {json.dumps(cmd)}',
        ])
        self.log_msg("Opened Terminal: brew install --cask powershell")

    def open_in_editor(self) -> None:
        s = self.selected_script()
        if not s:
            messagebox.showinfo("Open", "Select a script first.")
            return
        path = os.path.abspath(s["path"])
        host = platform.system()
        if host == "Windows" and path.lower().endswith(".ps1"):
            windir = os.environ.get("WINDIR", r"C:\Windows")
            ise = os.path.join(windir, "System32", "WindowsPowerShell", "v1.0", "PowerShell_ISE.exe")
            if os.path.isfile(ise):
                subprocess.Popen(f'"{ise}" -File "{path}" -NoProfile', shell=True)
                self.log_msg(f"Opened in PowerShell ISE: {path}")
                return
        if host == "Darwin":
            subprocess.Popen(["open", "-t", path])
        elif host == "Windows":
            os.startfile(path)  # type: ignore[attr-defined]
        else:
            subprocess.Popen(["xdg-open", path])
        self.log_msg(f"Opened: {path}")

    def open_folder(self) -> None:
        s = self.selected_script()
        if s and os.path.isfile(s["path"]):
            path = s["path"]
            if platform.system() == "Windows":
                subprocess.Popen(["explorer.exe", f'/select,"{path}"'])
            elif platform.system() == "Darwin":
                subprocess.Popen(["open", "-R", path])
            else:
                subprocess.Popen(["xdg-open", os.path.dirname(path)])
            self.log_msg(f"Selected in file manager: {path}")
            return
        if not self.selected_cat:
            messagebox.showinfo("Open Folder", "Select a category or script first.")
            return
        path = self.selected_cat["path"]
        if platform.system() == "Darwin":
            subprocess.Popen(["open", path])
        elif platform.system() == "Windows":
            os.startfile(path)  # type: ignore[attr-defined]
        else:
            subprocess.Popen(["xdg-open", path])
        self.log_msg(f"Opened: {path}")

    def _launch_mac_sh(self, path: str, *, dry: bool) -> None:
        directory, name = os.path.dirname(path), os.path.basename(path)
        if dry:
            cmd = (
                f'cd {json.dumps(directory)} && echo "=== DRY RUN / PREVIEW: {name} ===" && '
                f'echo "Env: DRY_RUN=YES WHATIF=YES" && echo && head -n 40 {json.dumps(path)} && echo && '
                f'echo "--- executing with DRY_RUN ---" && DRY_RUN=YES WHATIF=YES zsh {json.dumps(path)}; '
                f'echo; read -r "?Press Enter..."'
            )
        else:
            cmd = (
                f'cd {json.dumps(directory)} && echo "=== RUN ELEVATED: {name} ===" && '
                f'sudo zsh {json.dumps(path)}; echo; read -r "?Press Enter..."'
            )
        subprocess.Popen(["osascript", "-e", f'tell application "Terminal" to do script {json.dumps(cmd)}'])
        self.log_msg(("Preview (Dry Run) started — " if dry else "Run started (elevated Terminal) — ") + name)

    def _launch_ps1(self, path: str, *, dry: bool) -> None:
        host = platform.system()
        if host == "Windows":
            powershell = os.path.join(os.environ.get("WINDIR", r"C:\\Windows"),
                                      "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
            work = os.path.dirname(path)
            if dry:
                # Keep window open so preview is visible even if -WhatIf is unsupported
                ps = (
                    f"Set-Location -LiteralPath {json.dumps(work)}; "
                    f"Write-Host '=== DRY RUN / PREVIEW ===' -ForegroundColor Yellow; "
                    f"Write-Host {json.dumps(path)}; Write-Host ''; "
                    f"$ErrorActionPreference = 'Continue'; "
                    f"try {{ & {json.dumps(path)} -WhatIf }} catch {{ "
                    f"Write-Host $_.Exception.Message -ForegroundColor DarkYellow; "
                    f"Write-Host ''; Write-Host 'Note: script may not declare -WhatIf. No elevated changes were requested.' -ForegroundColor Gray "
                    f"}}; Write-Host ''; Read-Host 'Press Enter to close'"
                )
                subprocess.Popen([powershell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps])
                self.log_msg("Preview (Dry Run) started — no changes applied.")
            else:
                arg = f"-NoProfile -ExecutionPolicy Bypass -File \"{path}\""
                subprocess.Popen([
                    "powershell.exe", "-NoProfile", "-Command",
                    f"Start-Process -FilePath '{powershell}' -ArgumentList '{arg}' -Verb RunAs "
                    f"-WorkingDirectory '{work}'"
                ])
                self.log_msg("Run started (elevated window).")
            return
        if host == "Darwin":
            pwsh = find_pwsh()
            if not pwsh:
                messagebox.showwarning(
                    "PowerShell",
                    "Install PowerShell 7 (pwsh) to run .ps1 on Mac.\n\nbrew install --cask powershell",
                )
                return
            args = [pwsh, "-NoProfile", "-File", path] + (["-WhatIf"] if dry else [])
            if dry:
                subprocess.Popen(args, cwd=os.path.dirname(path))
                self.log_msg("Preview (Dry Run) started via pwsh -WhatIf.")
            else:
                quoted = " ".join(json.dumps(a) for a in args)
                cmd = f'cd {json.dumps(os.path.dirname(path))} && sudo {quoted}; echo; read -r "?Press Enter..."'
                subprocess.Popen(["osascript", "-e", f'tell application "Terminal" to do script {json.dumps(cmd)}'])
                self.log_msg("Run started (pwsh elevated in Terminal).")
            return
        messagebox.showwarning("Run", "Unsupported host OS.")

    def run_script(self) -> None:
        self._execute(dry=False)

    def dry_run_script(self) -> None:
        self._execute(dry=True)

    def _execute(self, *, dry: bool) -> None:
        s = self.selected_script()
        if not s:
            messagebox.showinfo("Select a script", "Select a script in the SCRIPTS column first.")
            self.log_msg("Select a script first.")
            return
        if not self.can_run_native():
            self._run_unavailable_msg()
            return
        path = s["path"]
        self.log_msg(s.get("label", path))
        self.log_msg(f"File: {s.get('file', Path(path).name)}")
        self.log_msg(f"Risk: {s.get('risk', 'Low')} | {s.get('care', '')}")
        if not self.confirm_risk(s, dry=dry):
            self.log_msg("Run cancelled by operator.")
            return
        if path.endswith(".sh"):
            if platform.system() != "Darwin":
                messagebox.showwarning("Run", "macOS .sh scripts must run on a Mac.")
                return
            self._launch_mac_sh(path, dry=dry)
            return
        if path.endswith(".ps1"):
            self._launch_ps1(path, dry=dry)
            return
        messagebox.showwarning("Run", "Unknown script type.")


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    platform_arg = role_arg = style_arg = None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--platform", "-Platform") and i + 1 < len(argv):
            platform_arg = argv[i + 1]; i += 2; continue
        if a in ("--role", "-Role") and i + 1 < len(argv):
            role_arg = argv[i + 1]; i += 2; continue
        if a in ("--style", "-Style") and i + 1 < len(argv):
            style_arg = argv[i + 1].strip().lower(); i += 2; continue
        i += 1

    catalog = discover()
    if not catalog:
        print("No categories found.", file=sys.stderr)
        return 2
    app = App(catalog, style=style_arg or "auto")
    if platform_arg in ("Windows", "macOS"):
        app.plat_var.set(platform_arg)
        app.on_platform()
    elif sys.platform == "darwin":
        app.plat_var.set("macOS")
        app.on_platform()
    if role_arg in ("SysAdmin", "ITSupport"):
        app.role_var.set(role_arg)
        app.on_role()
    center_on_screen(app, 1360, 780)
    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
