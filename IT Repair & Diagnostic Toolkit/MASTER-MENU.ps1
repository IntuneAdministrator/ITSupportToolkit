#Requires -Version 5.1
<#
.SYNOPSIS
    IT-Repair-Scripts master launcher (console + unified WPF GUI).
    Product name: IT Repair & Diagnostic Toolkit.
.DESCRIPTION
    Discovers Windows and macOS SysAdmin + ITSupport categories.
    GUI: Platform | Role | Theme (Break & Fix, Networking, M365, ...) | Category | Scripts.
.EXAMPLE
    .\MASTER-MENU.ps1 -Gui
.EXAMPLE
    .\MASTER-MENU.ps1
.NOTES
    Author: Allester Padovani
    Version: 1.6.0 | Windows PowerShell 5.1 / 7.x | ASCII + UTF-8 BOM safe
#>
[CmdletBinding()]
param(
    [switch]$Gui,
    [ValidateSet('Windows', 'macOS')]
    [string]$Platform = 'Windows',
    [ValidateSet('SysAdmin', 'ITSupport')]
    [string]$Role = 'SysAdmin'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:Root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Script:BrandName = 'IT Repair & Diagnostic Toolkit'
$Script:BrandTagline = 'Windows & macOS · SysAdmin & IT Support'
$Script:ProductVersion = '1.6.1'
$Script:BrandCopyright = [char]0x00A9 + " $((Get-Date).Year) Allester Padovani. All rights reserved."

function ConvertTo-XamlText {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    return ($Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
}
$Script:WinRoot = Join-Path $Script:Root 'Windows'
$Script:MacRoot = Join-Path $Script:Root 'macOS'
$Script:LogDir = 'C:\IT-Logs'
New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null

$Script:ThemeOrder = @(
    'Break & Fix'
    'Networking'
    'Antivirus & Security'
    'Microsoft 365'
    'Identity & Access'
    'MDM & Endpoint'
    'Devices & Peripherals'
    'Storage & Backup'
    'Updates & Patching'
    'Remote Access'
    'Performance & Diagnostics'
    'Print Services'
    'Cloud & Virtualization'
    'Apps & Browser'
    'Onboarding & Lifecycle'
    'Evidence & Reporting'
    'Other'
)

function Write-MenuStatus {
    param([string]$Message, [ValidateSet('INFO','SUCCESS','WARNING','ERROR')][string]$Level = 'INFO')
    $colors = @{ INFO = 'Cyan'; SUCCESS = 'Green'; WARNING = 'Yellow'; ERROR = 'Red' }
    Write-Host "[$Level] $(Get-Date -Format 'HH:mm:ss') $Message" -ForegroundColor $colors[$Level]
}

function Get-ThemeName {
    param([string]$FolderName)
    $n = $FolderName.ToLowerInvariant()
    if ($n -match 'imported-m365|m365-audit|m365-repair|audit-report') {
        return 'Microsoft 365'
    }
    if ($n -match 'imported-tech-support|tech-support-tools|troubleshoot') {
        return 'Devices & Peripherals'
    }
    if ($n -match 'imported-windows-repair|imported-windows-settings') {
        return 'Break & Fix'
    }
    if ($n -match 'm365|office|outlook|teams|onedrive|sharepoint|exchange|graph|email|calendar|collaboration|cloud-storage|mailbox') {
        return 'Microsoft 365'
    }
    if ($n -match 'malware|antivirus|edr|security|harden|firewall|asr|awareness|phishing|xprotect|gatekeeper|defender|filevault|sip-') {
        return 'Antivirus & Security'
    }
    if ($n -match 'certificate|keychain|pkcs|ssl-tls|cert-') {
        return 'Identity & Access'
    }
    if ($n -match 'network|dns|dhcp|vpn|connectivity|wifi|wireless|proxy|tcp|mtu|nrpt|aovpn|directaccess|bonjour') {
        return 'Networking'
    }
    if ($n -match 'identity|mfa|account|active-directory|entra|azure-ad|hello|credential|sso|unlock|password|signin|sign-in|auth|pim|ca-block|legacy-auth') {
        return 'Identity & Access'
    }
    if ($n -match 'runbook|intunewin|jamf-policy-template|jamf-self-service|intune-mac-runbook') {
        return 'Evidence & Reporting'
    }
    if ($n -match 'cmdb|inventory-export|servicenow|snipeit|lansweeper|asset-panda|tenant-device|endpoint-analytics') {
        return 'Onboarding & Lifecycle'
    }
    if ($n -match 'raid|iscsi|san-|storage-spaces|refs|hyper-v-host|vss-|megaraid|apfs-container|parallels-vm|vmware-fusion|timemachine-server|backup-vss') {
        return 'Storage & Backup'
    }
    if ($n -match 'kvm|aten|raritan|avocent|zebra|scanner|rfid|receipt-printer|powermic|stream-deck|piv|smartcard|yubikey|magtek|dictation|plotter|spacepilot|barcode|dock-firmware|wd19|caldigit|apple-silicon|magic-keyboard|warranty-lookup|gpu|quadro|nvidia-smi|egpu|thunderbolt-raid') {
        return 'Devices & Peripherals'
    }
    if ($n -match 'intune|jamf|autopilot|sccm|mecm|compliance|mdm|enrollment|purview|secure-score|dlp|intunewin|graph-mac|entra-mac') {
        return 'MDM & Endpoint'
    }
    if ($n -match 'usb|bluetooth|audio|video|webcam|display|hardware|dock|peripheral|laptop|battery|power|warranty|inventory|font|language|region|finder|spotlight|magic|headset|sd-card') {
        return 'Devices & Peripherals'
    }
    if ($n -match 'disk|storage|backup|vss|apfs|timemachine|time-machine|shadow|refs|spaces') {
        return 'Storage & Backup'
    }
    if ($n -match 'update|wsus|softwareupdate|patch|catalog') {
        return 'Updates & Patching'
    }
    if ($n -match 'rdp|remote-access|remote-tools|ard|ssh|remote-work|home-office|screensharing|vnc') {
        return 'Remote Access'
    }
    if ($n -match 'performance|telemetry|event-log|diagnostic|crash|slow-|process-service') {
        return 'Performance & Diagnostics'
    }
    if ($n -match 'print|cups|spooler') {
        return 'Print Services'
    }
    if ($n -match 'hyper-v|w365|cloud-pc|avd|virtual|docker|fslogix') {
        return 'Cloud & Virtualization'
    }
    if ($n -match 'browser|app-compat|appx|store|app-management|shim') {
        return 'Apps & Browser'
    }
    if ($n -match 'onboarding|offboarding|eol|migration|licensing|activation') {
        return 'Onboarding & Lifecycle'
    }
    if ($n -match 'evidence|reporting') {
        return 'Evidence & Reporting'
    }
    if ($n -match 'quick-fix|slow-pc|slow-mac|settings-repair|system-repair|system-information|file-repair|explorer|startup|login|boot|file-explorer|shell') {
        return 'Break & Fix'
    }
    return 'Other'
}

function Get-SafeCount {
    param($Value)
    if ($null -eq $Value) { return 0 }
    return @($Value).Count
}

function Get-CatalogStats {
    $cats = @(Get-AllCatalog)
    $win = [int]($cats | Where-Object Platform -eq 'Windows' | Measure-Object -Property Count -Sum).Sum
    $mac = [int]($cats | Where-Object Platform -eq 'macOS' | Measure-Object -Property Count -Sum).Sum
    [pscustomobject]@{
        Categories = (Get-SafeCount $cats)
        Windows    = $win
        Mac        = $mac
        Total      = $win + $mac
    }
}

function Get-AllCatalog {
    $cats = [System.Collections.Generic.List[object]]::new()
    $roots = @(
        @{ Platform = 'Windows'; Root = $Script:WinRoot; Exts = @('*.ps1') }
        @{ Platform = 'macOS';   Root = $Script:MacRoot; Exts = @('*.sh', '*.ps1') }
    )
    foreach ($r in $roots) {
        if (-not (Test-Path $r.Root)) { continue }
        foreach ($role in @('SysAdmin', 'ITSupport')) {
            $base = Join-Path $r.Root $role
            if (-not (Test-Path $base)) { continue }
            Get-ChildItem $base -Directory | Sort-Object Name | ForEach-Object {
                $scripts = [System.Collections.Generic.List[object]]::new()
                foreach ($ext in $r.Exts) {
                    Get-ChildItem $_.FullName -Filter $ext -File -ErrorAction SilentlyContinue | ForEach-Object {
                        # Skip markdown/readme helpers mistakenly matched (none for ps1/sh)
                        [void]$scripts.Add($_)
                    }
                }
                $scriptArr = @($scripts | Sort-Object Name)
                $roleLabel = if ($role -eq 'SysAdmin') { 'System Administrator' } else { 'IT Support' }
                $cats.Add([pscustomobject]@{
                    Platform    = $r.Platform
                    Role        = $role
                    RoleLabel   = $roleLabel
                    Name        = $_.Name
                    DisplayName = ($_.Name -replace '^\d+_', '' -replace '-', ' ')
                    Theme       = (Get-ThemeName -FolderName $_.Name)
                    Path        = $_.FullName
                    Scripts     = $scriptArr
                    Count       = $scriptArr.Count
                    Extension   = ($r.Exts -join ',')
                })
            }
        }
    }
    return $cats
}

function Get-ITCategories {
    # Console menu: Windows only (runnable here)
    return @(Get-AllCatalog | Where-Object Platform -eq 'Windows')
}

function Get-ScriptUiInfo {
    <#
    .SYNOPSIS
        Unique, detailed helpdesk label and risk for a script path.
        Every script gets a distinct Label (filename-derived topic + action + file name).
    .OUTPUTS
        PSCustomObject: Label, ListText, Risk, Care, Summary, InfoTip, InfoText, FileName, Topic, Action
    #>
    param([Parameter(Mandatory)][string]$Path)

    $file = Split-Path $Path -Leaf
    $leaf = [IO.Path]::GetFileNameWithoutExtension($Path)
    $n = $leaf.ToLowerInvariant()
    $words = [System.Collections.Generic.List[string]]::new()
    foreach ($chunk in @($leaf -split '[-_]+' | Where-Object { $_ })) {
        $parts = [regex]::Matches($chunk, '[A-Z]+(?=[A-Z][a-z]|[0-9]|$)|[A-Z]?[a-z]+|[0-9]+')
        if ($parts.Count -gt 0) {
            foreach ($m in $parts) {
                if ($m.Value -notmatch '^(?i:mac|win|client)$') { [void]$words.Add($m.Value) }
            }
        } elseif ($chunk -notmatch '^(?i:mac|win|client)$') {
            [void]$words.Add($chunk)
        }
    }
    if ($words.Count -eq 0) {
        foreach ($w in @($leaf -split '[-_]+' | Where-Object { $_ })) { [void]$words.Add($w) }
    }
    $topicParts = foreach ($w in $words) {
        if ($w.Length -le 4 -and $w -match '^[A-Za-z0-9]+$') { $w.ToUpperInvariant() }
        elseif ($w -cmatch '^[A-Z0-9]+$') { $w }
        elseif ($w -match '^[A-Za-z]') { ($w.Substring(0, 1).ToUpper() + $w.Substring(1).ToLower()) }
        else { $w }
    }
    $topicCore = ($topicParts -join ' ')
    if (-not $topicCore) { $topicCore = $leaf -replace '[-_]+', ' ' }

    # --- Risk ---
    $risk = 'Low'
    $care = 'Read-only / diagnostic. Low impact. Safe to run for troubleshooting; still confirm you selected the correct user/device.'
    if ($n -match 'wipe|destroy|format|diskpart|secure-erase|factory|reimage|shred|purge|delete|remove-profile|revoke|litigation-hold|quarantine|cancel-a|thinlocal|softwaredistribution-reset|csc-reset|boot-recovery|bcd-|offline-files.*reset|profile-list.*orphan|session-revoke|local-account-unlock|password-reset|bitlocker.*decrypt|fde.*off|sip.*disable') {
        $risk = 'Dangerous'
        $care = 'MAY DELETE DATA, BREAK SIGN-IN, OR CHANGE SECURITY. Open a ticket, notify the user, take a backup/restore point when possible, prefer Dry Run / -WhatIf first. Do not run at scale without approval. Confirm asset tag / username before continuing.'
    } elseif ($n -match 'reset|repair|fix|flush|clear|rebuild|force|renew|restart|reinstall|resync|compact|kickstart|killall|stop-service|rename|cleanup|deep-repair|stuck-job|ost-rebuild|cache-purge|token-clear|license-reset|activation-repair') {
        $risk = 'Caution'
        $care = 'Changes system or app configuration/cache. Close the affected app, notify the user, document what you change, and have rollback (restore point / WhatIf / re-login) ready. Verify the symptom matches this script before running.'
    }

    # Action tag + full unique topic (always includes filename → never duplicates)
    $action = 'Tool'
    $detail = 'run this script for the named area'
    switch -Regex ($n) {
        'all-in-one-triage|one-click-common' { $action = 'Triage'; $detail = 'automatic common-issue checks and basic repairs'; break }
        'whatif|guide|hint|prep|path-hint|portal' { $action = 'Guide'; $detail = 'reference / prep (minimal or no system change)'; break }
        'check|status|audit|report|detect|lookup|inventory|snapshot|digest|export' { $action = 'Check'; $detail = 'diagnostic / report'; break }
        'flush|clear|purge' { $action = 'Clear'; $detail = 'clears cache or temporary data'; break }
        'reset|repair|fix|rebuild|stack-reset|auto-repair|quick-fix' { $action = 'Repair'; $detail = 'repairs or resets the component'; break }
        'force|renew|kickstart' { $action = 'Force'; $detail = 'forces refresh or renewal'; break }
        'launch-' { $action = 'Launch'; $detail = 'opens imported tech-support tool'; break }
        'connect|install' { $action = 'Setup'; $detail = 'connection, install, or prep'; break }
    }

    $ext = [IO.Path]::GetExtension($Path).TrimStart('.').ToLowerInvariant()
    $plat = if ($n -match '-mac$' -or $ext -eq 'sh') { 'Mac' } elseif ($ext -eq 'ps1') { 'Win' } else { $ext.ToUpperInvariant() }
    $label = "[$action] $topicCore - $detail ($plat, $file)"
    if ($label.Length -gt 220) { $label = $label.Substring(0, 217) + '...' }

    $riskMeaning = switch ($risk) {
        'Dangerous' { 'HIGH IMPACT (red dot) — can delete data, break sign-in, wipe config, or change security posture. Treat like a change ticket.' }
        'Caution'   { 'CHANGES CONFIG (yellow dot) — modifies settings, cache, services, profiles, or app state. User may notice a restart or re-login.' }
        default     { 'SAFE / DIAGNOSTIC (green dot) — mainly read-only checks, reports, or low-impact tools. Still confirm the correct target first.' }
    }

    $summary = switch ($action) {
        'Triage' {
            @"
This is an automated triage helper for '$topicCore'.
It runs a bundle of common checks and may apply light, well-known fixes so you can narrow the incident faster without jumping between many menus.
Use it early in a ticket when the symptom is broad (e.g. "Outlook broken", "Wi-Fi weird", "PC slow") and you need a structured first pass.
"@.Trim()
        }
        'Guide' {
            @"
This opens guidance / prep steps for '$topicCore' with minimal or no system change ($detail).
Use it when you need the correct portal path, prerequisites, or a checklist before you run a repair script.
It is the safest place to start if you are unsure which repair to pick.
"@.Trim()
        }
        'Check' {
            @"
This collects diagnostic information or a report about '$topicCore' ($detail).
It is meant to confirm the root cause, gather evidence for the ticket, and decide whether a Clear / Repair / Force script is actually needed.
Prefer Check before Repair whenever the symptom is unclear.
"@.Trim()
        }
        'Clear' {
            @"
This clears cache or temporary data related to '$topicCore'.
Typical outcomes: corrupted local cache removed, app forced to rebuild local state, or stale tokens discarded.
The user may need to reopen the app, re-authenticate, or wait for a short re-sync afterward. Save their work first.
"@.Trim()
        }
        'Repair' {
            @"
This attempts to repair or reset '$topicCore' ($detail).
Expect configuration, service, profile, or client-stack changes on the target device. It is stronger than Clear and should follow a confirmed diagnosis.
Have a rollback plan (restore point, re-login, known-good profile, or Dry Run) before elevating.
"@.Trim()
        }
        'Force' {
            @"
This forces a refresh or renewal for '$topicCore' (sync, license, policy, connection, or similar).
It can briefly interrupt the related app or session while the refresh runs. Use when a normal retry is stuck and a Check already shows the component is unhealthy.
"@.Trim()
        }
        'Launch' {
            @"
This launches an imported tech-support tool focused on '$topicCore'.
You are leaving the launcher and entering another UI — read that tool's prompts carefully before applying changes. Do not assume the tool is read-only.
"@.Trim()
        }
        'Setup' {
            @"
This performs connection, install, or prep work for '$topicCore' ($detail).
Confirm network access, account permissions, and any required modules/licenses first. Failed setup often means missing prerequisites, not a bad script.
"@.Trim()
        }
        default {
            @"
This runs the toolkit script for '$topicCore' ($detail).
Read the risk level and care notes below before Dry Run or Run Elevated. If the label does not match the ticket symptom, stop and pick another script.
"@.Trim()
        }
    }

    $whenToUse = switch ($action) {
        'Triage'  { 'First-pass / unknown root cause; you need a structured sweep of common failure points.' }
        'Guide'   { 'Before changing anything; you need instructions, portal steps, or prerequisites.' }
        'Check'   { 'To prove the issue, capture evidence, or choose the next repair safely.' }
        'Clear'   { 'When cache/temp state is suspected (stuck sign-in, stale mailbox, corrupt local app data).' }
        'Repair'  { 'When diagnosis already points to a broken component that needs reset/rebuild.' }
        'Force'   { 'When a sync/license/policy refresh is stuck and Check shows it is not updating.' }
        'Launch'  { 'When a specialized imported tool is the right next step for this topic.' }
        'Setup'   { 'When installing, connecting, or preparing the named service/client.' }
        default   { 'When the script topic matches the ticket and you understand the risk level.' }
    }

    $expect = switch ($risk) {
        'Dangerous' { 'Possible data loss, sign-in impact, or security change. User communication and approval are mandatory.' }
        'Caution'   { 'App restart, re-login, short downtime, or visible config change is normal.' }
        default     { 'Mostly information on screen / in STATUS. Little or no lasting change if it is a pure Check/Guide.' }
    }

    $infoTip = @"
$summary

When to use: $whenToUse
Risk: $risk — $riskMeaning
Care: $care
File: $file ($plat)
"@.Trim()

    $infoText = @"
SCRIPT INFORMATION — read carefully before Dry Run or Run Elevated

══════════════════════════════════════════════════════════════
1) WHAT THIS SCRIPT DOES
══════════════════════════════════════════════════════════════
$summary

List label in SCRIPTS:
$label

══════════════════════════════════════════════════════════════
2) WHEN A TECHNICIAN SHOULD USE IT
══════════════════════════════════════════════════════════════
$whenToUse

Do NOT use it if:
  • The ticket symptom does not match '$topicCore'
  • You have not identified the correct user / device / mailbox / tenant
  • A safer Check or Guide script exists and you have not tried it yet (when applicable)

══════════════════════════════════════════════════════════════
3) RISK LEVEL (matches the colored dot)
══════════════════════════════════════════════════════════════
$risk — $riskMeaning

Legend:
  • Green  = safe / diagnostic (Low)
  • Yellow = changes config (Caution)
  • Red    = high impact (Dangerous)

Expected impact after running:
$expect

══════════════════════════════════════════════════════════════
4) CARE / PRECAUTIONS (checklist)
══════════════════════════════════════════════════════════════
$care

Technician checklist before Run Elevated:
  [ ] Correct PLATFORM selected (Windows vs macOS)
  [ ] Correct ROLE selected (SysAdmin vs IT Support)
  [ ] Correct user / device / ticket confirmed
  [ ] User notified if the app may close or they may need to sign in again
  [ ] Dry Run (Preview) used first when the script supports it
  [ ] Rollback plan ready (restore point, backup, known-good profile, or reinstall path)

══════════════════════════════════════════════════════════════
5) FILE / PLATFORM
══════════════════════════════════════════════════════════════
File name : $file
Platform  : $plat
Action tag: $action
Topic     : $topicCore
Full path :
$Path

Tip: keep this window open while you brief the user. Prefer Dry Run, then Run Elevated only after the preview looks correct.
"@.Trim()

    [pscustomobject]@{
        Label    = $label
        ListText = $label
        Risk     = $risk
        Care     = $care
        Summary  = $summary
        InfoTip  = $infoTip
        InfoText = $infoText
        FileName = $file
        Topic    = $topicCore
        Action   = $action
    }
}

function Get-RiskCircleColor {
    param([string]$Risk)
    switch ($Risk) {
        'Dangerous' { 'Red' }
        'Caution'   { 'Yellow' }
        default     { 'Green' }
    }
}

function Write-RiskCircle {
    param([string]$Risk)
    Write-Host ([char]0x25CF) -ForegroundColor (Get-RiskCircleColor -Risk $Risk) -NoNewline
}

function Get-ScriptDescription {
    param([string]$Path)
    return (Get-ScriptUiInfo -Path $Path).Label
}

function Test-IsAdministrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = [Security.Principal.WindowsPrincipal]$id
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-ElevatedScript {
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [switch]$WhatIf
    )
    if (-not (Test-Path $ScriptPath)) {
        Write-MenuStatus "Script not found: $ScriptPath" -Level ERROR
        return
    }
    if ($ScriptPath -like '*.sh') {
        Write-MenuStatus "macOS scripts cannot run on Windows. Copy path or open folder instead." -Level WARNING
        return
    }
    $argWhatIf = if ($WhatIf) { ' -WhatIf' } else { '' }
    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"$argWhatIf"
    Write-MenuStatus "Launching: $(Split-Path $ScriptPath -Leaf)" -Level INFO
    try {
        if (Test-IsAdministrator) {
            Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -WorkingDirectory (Split-Path $ScriptPath -Parent)
        } else {
            Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -Verb RunAs -WorkingDirectory (Split-Path $ScriptPath -Parent)
        }
        Write-MenuStatus "Started elevated PowerShell for script." -Level SUCCESS
    } catch {
        Write-MenuStatus "Launch failed: $($_.Exception.Message)" -Level ERROR
    }
}

function Show-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '  +==========================================================+' -ForegroundColor Cyan
    Write-Host '  |     IT REPAIR & DIAGNOSTIC TOOLKIT - MASTER MENU     |' -ForegroundColor Cyan
    Write-Host ("  |     Windows + macOS catalog  |  v{0}              |" -f $Script:ProductVersion) -ForegroundColor Cyan
    Write-Host '  +==========================================================+' -ForegroundColor Cyan
    Write-Host ''
    $stats = Get-CatalogStats
    Write-Host ("  Scripts: {0} total ({1} Windows .ps1, {2} macOS .sh) | {3} categories" -f $stats.Total, $stats.Windows, $stats.Mac, $stats.Categories) -ForegroundColor DarkGray
    $join = 'Unknown'
    try {
        $ds = & dsregcmd /status 2>&1 | Out-String
        if ($ds -match 'AzureAdJoined\s*:\s*YES' -and $ds -match 'DomainJoined\s*:\s*YES') { $join = 'Hybrid' }
        elseif ($ds -match 'DomainJoined\s*:\s*YES') { $join = 'On-prem AD' }
        elseif ($ds -match 'AzureAdJoined\s*:\s*YES') { $join = 'Entra ID' }
        else { $join = 'Workgroup' }
    } catch { }
    Write-Host "  Host: $env:COMPUTERNAME  |  Join: $join  |  Admin: $(Test-IsAdministrator)" -ForegroundColor DarkGray
    Write-Host "  Root: $Script:Root" -ForegroundColor DarkGray
    Write-Host ''
}

function Read-MenuChoice {
    param([int]$Min, [int]$Max, [string]$Prompt = 'Select')
    while ($true) {
        Write-Host -NoNewline "  $Prompt [$Min-$Max, G=GUI, Q=Quit]: " -ForegroundColor Yellow
        $line = Read-Host
        if ($null -eq $line) { continue }
        $t = $line.Trim()
        if ($t -match '^[Qq]$') { return 'QUIT' }
        if ($t -match '^[Gg]$') { return 'GUI' }
        $n = 0
        if ([int]::TryParse($t, [ref]$n) -and $n -ge $Min -and $n -le $Max) { return $n }
        Write-Host '  Invalid selection.' -ForegroundColor Red
    }
}

function Show-ArrowList {
    param(
        [Parameter(Mandatory)][string[]]$Items,
        [string]$Title = 'Select'
    )
    if (-not $Items -or $Items.Count -eq 0) { return -1 }
    $idx = 0
    $offset = 0
    $page = 18
    while ($true) {
        Clear-Host
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host '  ^/v move  Enter select  Esc/Q back' -ForegroundColor DarkGray
        Write-Host ''
        $end = [Math]::Min($offset + $page - 1, $Items.Count - 1)
        if ($Items.Count -gt $page) {
            Write-Host ("  . showing {0}-{1} of {2}" -f ($offset + 1), ($end + 1), $Items.Count) -ForegroundColor DarkGray
        }
        for ($i = $offset; $i -le $end; $i++) {
            if ($i -eq $idx) {
                Write-Host ("  > {0}" -f $Items[$i]) -ForegroundColor Black -BackgroundColor Cyan
            } else {
                Write-Host ("    {0}" -f $Items[$i]) -ForegroundColor White
            }
        }
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        switch ($key.VirtualKeyCode) {
            38 { if ($idx -gt 0) { $idx-- }; if ($idx -lt $offset) { $offset = $idx } }
            40 { if ($idx -lt $Items.Count - 1) { $idx++ }; if ($idx -gt $end) { $offset = $idx - $page + 1 } }
            13 { return $idx }
            27 { return -1 }
            81 { return -1 }
        }
    }
}

function Start-ConsoleMenu {
    $categories = @(Get-ITCategories)
    if ($categories.Count -eq 0) {
        Write-MenuStatus "No Windows categories found under $Script:WinRoot" -Level ERROR
        return
    }
    while ($true) {
        Show-Banner
        Write-Host '  CATEGORIES (Windows runnable)' -ForegroundColor Cyan
        Write-Host '  ----------------------------------------' -ForegroundColor DarkCyan
        $i = 1
        foreach ($c in $categories) {
            Write-Host ("  {0,2}. [{1}] {2} / {3} ({4})" -f $i, $c.RoleLabel, $c.Theme, $c.DisplayName, $c.Count) -ForegroundColor White
            $i++
        }
        Write-Host ''
        Write-Host '  [A] Arrow-key category picker' -ForegroundColor DarkGray
        Write-Host '  [G] Launch unified WPF GUI (Windows + macOS catalog)' -ForegroundColor DarkGray
        Write-Host '  [Q] Quit' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host -NoNewline '  Select category (number / A / G / Q): ' -ForegroundColor Yellow
        $sel = Read-Host
        if ([string]::IsNullOrWhiteSpace($sel)) { continue }
        $t = $sel.Trim()
        if ($t -match '^[Qq]$') { break }
        if ($t -match '^[Gg]$') { Start-WpfGui; continue }
        if ($t -match '^[Aa]$') {
            $labels = @($categories | ForEach-Object { "[{0}] {1} | {2} ({3})" -f $_.RoleLabel, $_.Theme, $_.DisplayName, $_.Count })
            $ci = Show-ArrowList -Items $labels -Title 'Select category'
            if ($ci -lt 0) { continue }
            Show-ScriptMenu -Category $categories[$ci]
            continue
        }
        $n = 0
        if ([int]::TryParse($t, [ref]$n) -and $n -ge 1 -and $n -le $categories.Count) {
            Show-ScriptMenu -Category $categories[$n - 1]
        } else {
            Write-Host '  Invalid selection.' -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

function Show-ScriptMenu {
    param($Category)
    while ($true) {
        Show-Banner
        Write-Host ("  {0} | {1} | {2}" -f $Category.RoleLabel, $Category.Theme, $Category.DisplayName) -ForegroundColor Cyan
        Write-Host '  ----------------------------------------' -ForegroundColor DarkCyan
        if ($Category.Scripts.Count -eq 0) {
            Write-Host '  (no scripts)' -ForegroundColor Yellow
            Write-Host ''
            Write-Host '  Press Enter to go back...' -ForegroundColor DarkGray
            [void](Read-Host)
            return
        }
        $i = 1
        foreach ($s in $Category.Scripts) {
            $ui = Get-ScriptUiInfo -Path $s.FullName
            Write-Host ("  {0,2}. " -f $i) -NoNewline
            Write-RiskCircle -Risk $ui.Risk
            Write-Host (' ' + $ui.Label) -ForegroundColor White
            if ($ui.Risk -ne 'Low') {
                Write-Host ("      Warning: {0}" -f $ui.Care) -ForegroundColor DarkYellow
            }
            $i++
        }
        Write-Host ''
        Write-Host '  [A] Arrow-key script picker' -ForegroundColor DarkGray
        Write-Host '  [B] Back  [Q] Quit' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host -NoNewline '  Select script (number / A / B / Q): ' -ForegroundColor Yellow
        $sel = Read-Host
        if ([string]::IsNullOrWhiteSpace($sel)) { continue }
        $t = $sel.Trim()
        if ($t -match '^[Bb]$') { return }
        if ($t -match '^[Qq]$') { exit 0 }
        if ($t -match '^[Aa]$') {
            $labels = @($Category.Scripts | ForEach-Object {
                    $ui = Get-ScriptUiInfo $_.FullName
                    if ($ui.ListText.Length -gt 90) { $ui.ListText.Substring(0, 87) + '...' } else { $ui.ListText }
                })
            $si = Show-ArrowList -Items $labels -Title ("Scripts - {0}" -f $Category.DisplayName)
            if ($si -lt 0) { continue }
            Confirm-And-Run -ScriptPath $Category.Scripts[$si].FullName
            continue
        }
        $n = 0
        if ([int]::TryParse($t, [ref]$n) -and $n -ge 1 -and $n -le $Category.Scripts.Count) {
            Confirm-And-Run -ScriptPath $Category.Scripts[$n - 1].FullName
        } else {
            Write-Host '  Invalid selection.' -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

function Confirm-And-Run {
    param([string]$ScriptPath)
    $ui = Get-ScriptUiInfo -Path $ScriptPath
    Write-Host ''
    Write-Host -NoNewline '  '
    Write-RiskCircle -Risk 'Low'
    Write-Host ' safe  ' -NoNewline -ForegroundColor DarkGray
    Write-RiskCircle -Risk 'Caution'
    Write-Host ' changes config  ' -NoNewline -ForegroundColor DarkGray
    Write-RiskCircle -Risk 'Dangerous'
    Write-Host ' high impact' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host "  $($ui.Label)" -ForegroundColor Cyan
    Write-Host "  File: $($ui.FileName)" -ForegroundColor DarkGray
    Write-Host "  Risk: $($ui.Risk)" -ForegroundColor $(switch ($ui.Risk) { 'Dangerous' { 'Red' } 'Caution' { 'Yellow' } default { 'Green' } })
    Write-Host "  Warning: $($ui.Care)" -ForegroundColor DarkYellow
    if ($ui.Risk -eq 'Dangerous') {
        Write-Host '  This script is DANGEROUS. Type YES to continue.' -ForegroundColor Red
        Write-Host -NoNewline '  Confirm: ' -ForegroundColor Yellow
        $confirm = Read-Host
        if ($confirm -ne 'YES') { Write-Host '  Cancelled.' -ForegroundColor DarkGray; return }
    }
    Write-Host '  [R] Run  [P] Preview (Dry Run)  [C] Cancel' -ForegroundColor Yellow
    Write-Host -NoNewline '  Choice: ' -ForegroundColor Yellow
    $c = Read-Host
    switch -Regex ($c) {
        '^[Rr]$' { Start-ElevatedScript -ScriptPath $ScriptPath; Start-Sleep -Seconds 1 }
        '^[PpDdWw]$' { Start-ElevatedScript -ScriptPath $ScriptPath -WhatIf; Start-Sleep -Seconds 1 }
        default { }
    }
}

function Start-WpfGui {
    Write-MenuStatus 'Starting unified WPF GUI...' -Level INFO
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

    $script:GuiCatalog = @(Get-AllCatalog)
    $script:FilteredCategories = @()
    $script:SelectedCategory = $null
    $script:SelectedScripts = @()
    $script:Platform = $Platform
    $script:Role = $Role
    if ($script:Platform -notin @('Windows', 'macOS')) { $script:Platform = 'Windows' }
    if ($script:Role -notin @('SysAdmin', 'ITSupport')) { $script:Role = 'SysAdmin' }

    $xamlBrandName = ConvertTo-XamlText -Text $Script:BrandName
    $xamlBrandTagline = ConvertTo-XamlText -Text $Script:BrandTagline
    $xamlBrandCopyright = ConvertTo-XamlText -Text $Script:BrandCopyright
    $xamlWindowTitle = ConvertTo-XamlText -Text "$Script:BrandName - Unified Launcher v$($Script:ProductVersion)"

    $listItemStyle = @"
            <ListBox.ItemContainerStyle>
              <Style TargetType="ListBoxItem">
                <Setter Property="Padding" Value="8,5"/>
                <Setter Property="Margin" Value="0,1"/>
                <Setter Property="Template">
                  <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                      <Border x:Name="Bd" Background="Transparent" CornerRadius="8" Padding="{TemplateBinding Padding}">
                        <ContentPresenter HorizontalAlignment="Stretch"/>
                      </Border>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsSelected" Value="True">
                          <Setter TargetName="Bd" Property="Background" Value="#2b4c7e"/>
                        </Trigger>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter TargetName="Bd" Property="Background" Value="#232a3b"/>
                        </Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate>
                  </Setter.Value>
                </Setter>
              </Style>
            </ListBox.ItemContainerStyle>
"@

    $scriptListTemplate = @"
            <ListBox.ItemTemplate>
              <DataTemplate>
                <StackPanel Orientation="Horizontal">
                  <Button Content="&#x2139;" Cursor="Hand" Margin="0,0,6,0" Padding="2,0"
                          FontSize="14" FontWeight="SemiBold" Focusable="False"
                          Foreground="{Binding InfoBrush}" VerticalAlignment="Top"
                          ToolTipService.ShowDuration="60000"
                          Tag="ScriptInfo">
                    <Button.Template>
                      <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="Transparent" Padding="{TemplateBinding Padding}" CornerRadius="4">
                          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                          <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="Bd" Property="Opacity" Value="0.7"/>
                          </Trigger>
                          <Trigger Property="IsPressed" Value="True">
                            <Setter TargetName="Bd" Property="Opacity" Value="0.55"/>
                          </Trigger>
                        </ControlTemplate.Triggers>
                      </ControlTemplate>
                    </Button.Template>
                    <Button.ToolTip>
                      <ToolTip Background="{Binding TipBg}" Foreground="{Binding TipFg}"
                               BorderBrush="{Binding TipBorder}" BorderThickness="1" Padding="10,8"
                               MaxWidth="440">
                        <TextBlock Text="{Binding InfoTip}" TextWrapping="Wrap"
                                   Foreground="{Binding TipFg}" FontFamily="Segoe UI" FontSize="12"/>
                      </ToolTip>
                    </Button.ToolTip>
                  </Button>
                  <Ellipse Width="10" Height="10" Margin="0,4,8,0" VerticalAlignment="Top" Fill="{Binding RiskBrush}"/>
                  <TextBlock Text="{Binding Label}" TextWrapping="NoWrap" TextTrimming="None"
                             Foreground="{Binding LabelBrush}" VerticalAlignment="Center"/>
                </StackPanel>
              </DataTemplate>
            </ListBox.ItemTemplate>
"@

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$xamlWindowTitle" Height="780" Width="1360"
        WindowStartupLocation="Manual" Background="#0b0f17"
        Foreground="#e2e8f0" FontFamily="Segoe UI">
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="130"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Grid Grid.Row="0" Margin="0,0,0,10">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0" VerticalAlignment="Center">
        <TextBlock x:Name="TitleText" Text="$xamlBrandName" FontSize="20" FontWeight="SemiBold" Foreground="#63b3ed" TextWrapping="Wrap"/>
        <TextBlock x:Name="Subtitle" Text="$xamlBrandTagline" Foreground="#718096" Margin="0,2,0,0" FontSize="12"/>
      </StackPanel>
      <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,12,0">
        <TextBlock x:Name="LblSearch" Text="Search Scripts" VerticalAlignment="Center"
                   Margin="0,0,10,0" FontSize="13" FontWeight="SemiBold" Foreground="#a0aec0"/>
        <TextBox x:Name="SearchBox" Width="280" Height="34"
                 VerticalContentAlignment="Center" Padding="10,0"
                 BorderThickness="1"
                 ToolTip="Filter categories and scripts by name or keyword"/>
      </StackPanel>
      <Button x:Name="BtnThemeToggle" Grid.Column="3" Height="34" MinWidth="132"
              Background="#121826" Foreground="#ffffff" BorderBrush="#2d3748" BorderThickness="1"
              Cursor="Hand" FontSize="12" FontWeight="SemiBold"
              ToolTip="Switch between dark and light appearance for the entire launcher."/>
    </Grid>

    <Border x:Name="PanelPlatform" Grid.Row="1" Background="#121826" BorderBrush="#2d3748" BorderThickness="1"
            CornerRadius="12" Padding="12" Margin="0,0,0,8" SnapsToDevicePixels="True">
      <StackPanel>
        <TextBlock x:Name="LblPlatform" Text="PLATFORM" FontSize="11" FontWeight="Bold" Foreground="#90cdf4" Margin="0,0,0,6"/>
        <StackPanel Orientation="Horizontal">
          <RadioButton x:Name="RbWin" Content="Windows" IsChecked="True" Margin="0,0,18,0"
                       Foreground="#e2e8f0" GroupName="Platform" FontSize="14"/>
          <RadioButton x:Name="RbMac" Content="macOS" Margin="0,0,18,0"
                       Foreground="#e2e8f0" GroupName="Platform" FontSize="14"/>
          <TextBlock x:Name="PlatformHint" Text="Windows scripts run elevated on this PC"
                     VerticalAlignment="Center" Foreground="#68d391" FontSize="12"/>
        </StackPanel>
      </StackPanel>
    </Border>

    <Border x:Name="PanelRole" Grid.Row="2" Background="#121826" BorderBrush="#2d3748" BorderThickness="1"
            CornerRadius="12" Padding="12" Margin="0,0,0,8" SnapsToDevicePixels="True">
      <StackPanel>
        <TextBlock x:Name="LblRole" Text="ROLE" FontSize="11" FontWeight="Bold" Foreground="#90cdf4" Margin="0,0,0,6"/>
        <StackPanel Orientation="Horizontal">
          <RadioButton x:Name="RbSA" Content="System Administrator" IsChecked="True" Margin="0,0,18,0"
                       Foreground="#e2e8f0" GroupName="Role" FontSize="14"/>
          <RadioButton x:Name="RbIT" Content="IT Support" Margin="0,0,18,0"
                       Foreground="#e2e8f0" GroupName="Role" FontSize="14"/>
        </StackPanel>
      </StackPanel>
    </Border>

    <Grid Grid.Row="3">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="280" MinWidth="220"/>
        <ColumnDefinition Width="10"/>
        <ColumnDefinition Width="360" MinWidth="280"/>
        <ColumnDefinition Width="10"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <Border x:Name="PanelTheme" Grid.Column="0" Background="#121826" BorderBrush="#2d3748" BorderThickness="1"
              CornerRadius="12" Padding="10" SnapsToDevicePixels="True">
        <DockPanel>
          <TextBlock x:Name="LblTheme" DockPanel.Dock="Top" Text="THEME" FontSize="11" FontWeight="Bold" Foreground="#f6ad55" Margin="4,0,0,8"/>
          <ListBox x:Name="ThemeList" Background="Transparent" BorderThickness="0" Foreground="#e2e8f0"
                   ScrollViewer.HorizontalScrollBarVisibility="Disabled"
                   ScrollViewer.VerticalScrollBarVisibility="Auto"
                   HorizontalContentAlignment="Stretch">
$listItemStyle
            <ListBox.ItemTemplate>
              <DataTemplate>
                <TextBlock Text="{Binding}" TextWrapping="Wrap" TextTrimming="None"
                           FontSize="13" Margin="2,1"/>
              </DataTemplate>
            </ListBox.ItemTemplate>
          </ListBox>
        </DockPanel>
      </Border>

      <Border x:Name="PanelCategory" Grid.Column="2" Background="#121826" BorderBrush="#2d3748" BorderThickness="1"
              CornerRadius="12" Padding="10" SnapsToDevicePixels="True">
        <DockPanel>
          <TextBlock x:Name="LblCategory" DockPanel.Dock="Top" Text="CATEGORY" FontSize="11" FontWeight="Bold" Foreground="#f6ad55" Margin="4,0,0,8"/>
          <ListBox x:Name="CategoryList" Background="Transparent" BorderThickness="0" Foreground="#e2e8f0"
                   ScrollViewer.HorizontalScrollBarVisibility="Disabled"
                   ScrollViewer.VerticalScrollBarVisibility="Auto"
                   HorizontalContentAlignment="Stretch">
$listItemStyle
            <ListBox.ItemTemplate>
              <DataTemplate>
                <TextBlock Text="{Binding}" TextWrapping="Wrap" TextTrimming="None"
                           FontSize="13" Margin="2,1"/>
              </DataTemplate>
            </ListBox.ItemTemplate>
          </ListBox>
        </DockPanel>
      </Border>

      <Border x:Name="PanelScripts" Grid.Column="4" Background="#121826" BorderBrush="#2d3748" BorderThickness="1"
              CornerRadius="12" Padding="10" SnapsToDevicePixels="True">
        <DockPanel>
          <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="4,0,0,8">
            <TextBlock x:Name="LblScripts" Text="SCRIPTS" FontSize="11" FontWeight="Bold" Foreground="#f6ad55" VerticalAlignment="Center" Margin="0,0,10,0"/>
            <Ellipse Width="8" Height="8" Fill="#48bb78" VerticalAlignment="Center" Margin="0,0,4,0"/>
            <TextBlock x:Name="LegendSafeText" Text="safe" FontSize="11" Foreground="#a0aec0" VerticalAlignment="Center" Margin="0,0,12,0"/>
            <Ellipse Width="8" Height="8" Fill="#ecc94b" VerticalAlignment="Center" Margin="0,0,4,0"/>
            <TextBlock x:Name="LegendCautionText" Text="changes config" FontSize="11" Foreground="#a0aec0" VerticalAlignment="Center" Margin="0,0,12,0"/>
            <Ellipse Width="8" Height="8" Fill="#fc8181" VerticalAlignment="Center" Margin="0,0,4,0"/>
            <TextBlock x:Name="LegendDangerText" Text="high impact" FontSize="11" Foreground="#a0aec0" VerticalAlignment="Center"/>
          </StackPanel>
          <ListBox x:Name="ScriptList" Background="Transparent" BorderThickness="0" Foreground="#e2e8f0">
$listItemStyle
$scriptListTemplate
          </ListBox>
        </DockPanel>
      </Border>
    </Grid>

    <StackPanel Grid.Row="4" Orientation="Horizontal" Margin="0,10,0,8" HorizontalAlignment="Right">
      <Button x:Name="BtnOpenFolder" Content="Open Folder" Width="118" Height="36" Margin="0,0,8,0"
              Background="#2d3748" Foreground="#e2e8f0" BorderBrush="#4a5568" BorderThickness="1" Cursor="Hand"
              ToolTip="Opens Explorer. If a script is selected, highlights that file without running it."/>
      <Button x:Name="BtnOpenIse" Content="Open in ISE" Width="128" Height="36" Margin="0,0,8,0"
              Background="#2d3748" Foreground="#e2e8f0" BorderBrush="#4a5568" BorderThickness="1" Cursor="Hand"
              ToolTip="Opens the selected .ps1 script in Windows PowerShell ISE (does not run it)."/>
      <Button x:Name="BtnWhatIf" Content="Dry Run (Preview)" Width="148" Height="36" Margin="0,0,8,0"
              Background="#744210" Foreground="#faf089" BorderBrush="#faf089" BorderThickness="1" Cursor="Hand"
              ToolTip="Preview only: shows what the script would change without applying it."/>
      <Button x:Name="BtnRun" Width="180" Height="36"
              Background="#2b6cb0" Foreground="White" BorderBrush="#63b3ed" BorderThickness="1" Cursor="Hand" FontWeight="SemiBold"
              ToolTip="Runs the selected script elevated (administrator)."/>
    </StackPanel>

    <Border x:Name="PanelStatus" Grid.Row="5" Background="#121826" BorderBrush="#2d3748" BorderThickness="1"
            CornerRadius="12" Padding="12" SnapsToDevicePixels="True">
      <DockPanel>
        <TextBlock x:Name="LblStatus" DockPanel.Dock="Top" Text="STATUS" FontSize="11" FontWeight="Bold" Foreground="#90cdf4" Margin="0,0,0,6"/>
        <Border x:Name="OutputCard" Background="#0b0f17" CornerRadius="8" Padding="6" BorderBrush="#1a202c" BorderThickness="1">
          <TextBox x:Name="OutputBox" IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True"
                   VerticalScrollBarVisibility="Auto" Background="Transparent" Foreground="#a0aec0"
                   BorderThickness="0" FontFamily="Consolas" FontSize="12"/>
        </Border>
      </DockPanel>
    </Border>

    <TextBlock x:Name="LblCopyright" Grid.Row="6" Text="$xamlBrandCopyright"
               FontSize="11" Foreground="#718096" HorizontalAlignment="Center"
               Margin="0,8,0,0" TextWrapping="Wrap"/>
  </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $themeList = $window.FindName('ThemeList')
    $categoryList = $window.FindName('CategoryList')
    $scriptList = $window.FindName('ScriptList')
    $btnRun = $window.FindName('BtnRun')
    $btnWhatIf = $window.FindName('BtnWhatIf')
    $btnOpenIse = $window.FindName('BtnOpenIse')
    $btnOpen = $window.FindName('BtnOpenFolder')
    $outputBox = $window.FindName('OutputBox')

    function Set-RunAsAdminButtonContent {
        param([System.Windows.Controls.Button]$Button)
        $panel = New-Object System.Windows.Controls.StackPanel
        $panel.Orientation = [System.Windows.Controls.Orientation]::Horizontal

        $iconAdded = $false
        try {
            # Imaging lives in PresentationCore (already loaded) — not a separate Interop assembly
            Add-Type -AssemblyName System.Drawing -ErrorAction Stop
            $shield = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
                [System.Drawing.SystemIcons]::Shield.Handle,
                [System.Windows.Int32Rect]::Empty,
                [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions()
            )
            $img = New-Object System.Windows.Controls.Image
            $img.Source = $shield
            $img.Width = 18
            $img.Height = 18
            $img.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
            $img.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            [void]$panel.Children.Add($img)
            $iconAdded = $true
        }
        catch {
            # Fallback: Segoe MDL2 Assets admin/shield glyph (no extra assemblies)
            $glyph = New-Object System.Windows.Controls.TextBlock
            $glyph.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe MDL2 Assets')
            $glyph.Text = [char]0xE7EF
            $glyph.FontSize = 16
            $glyph.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
            $glyph.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $glyph.Foreground = [System.Windows.Media.Brushes]::White
            [void]$panel.Children.Add($glyph)
            $iconAdded = $true
        }

        $label = New-Object System.Windows.Controls.TextBlock
        $label.Text = 'Run Elevated'
        $label.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $label.Foreground = [System.Windows.Media.Brushes]::White
        $label.FontWeight = [System.Windows.FontWeights]::SemiBold
        [void]$panel.Children.Add($label)
        $Button.Content = $panel
    }
    try {
        Set-RunAsAdminButtonContent -Button $btnRun
    }
    catch {
        $btnRun.Content = 'Run Elevated'
    }
    $subtitle = $window.FindName('Subtitle')
    $rbWin = $window.FindName('RbWin')
    $rbMac = $window.FindName('RbMac')
    $rbSA = $window.FindName('RbSA')
    $rbIT = $window.FindName('RbIT')
    $platformHint = $window.FindName('PlatformHint')
    $searchBox = $window.FindName('SearchBox')
    $lblSearch = $window.FindName('LblSearch')
    $btnThemeToggle = $window.FindName('BtnThemeToggle')
    $titleText = $window.FindName('TitleText')
    $panelPlatform = $window.FindName('PanelPlatform')
    $panelRole = $window.FindName('PanelRole')
    $panelTheme = $window.FindName('PanelTheme')
    $panelCategory = $window.FindName('PanelCategory')
    $panelScripts = $window.FindName('PanelScripts')
    $panelStatus = $window.FindName('PanelStatus')
    $outputCard = $window.FindName('OutputCard')
    $lblPlatform = $window.FindName('LblPlatform')
    $lblRole = $window.FindName('LblRole')
    $lblTheme = $window.FindName('LblTheme')
    $lblCategory = $window.FindName('LblCategory')
    $lblScripts = $window.FindName('LblScripts')
    $lblStatus = $window.FindName('LblStatus')
    $lblCopyright = $window.FindName('LblCopyright')
    $legendSafeText = $window.FindName('LegendSafeText')
    $legendCautionText = $window.FindName('LegendCautionText')
    $legendDangerText = $window.FindName('LegendDangerText')

    $script:GuiStats = Get-CatalogStats
    $subtitle.Text = ("{0} | {1} Windows + {2} macOS scripts | {3} categories" -f $Script:BrandTagline, $script:GuiStats.Windows, $script:GuiStats.Mac, $script:GuiStats.Categories)

    $script:UiThemePrefPath = Join-Path $Script:Root 'toolkit-theme.cfg'
    $script:UiThemePrefLegacy = Join-Path $Script:Root 'gui-color-theme.txt'
    $script:UiColorMode = 'Light'
    if (-not (Test-Path -LiteralPath $script:UiThemePrefPath) -and (Test-Path -LiteralPath $script:UiThemePrefLegacy)) {
        try {
            Move-Item -LiteralPath $script:UiThemePrefLegacy -Destination $script:UiThemePrefPath -Force
        } catch {
            try { Copy-Item -LiteralPath $script:UiThemePrefLegacy -Destination $script:UiThemePrefPath -Force } catch { }
        }
    }
    $script:BrushConverter = [System.Windows.Media.BrushConverter]::new()

    function ConvertTo-UiBrush([string]$Hex) {
        return $script:BrushConverter.ConvertFromString($Hex)
    }

    function Get-UiThemePalette {
        param([ValidateSet('Dark', 'Light')][string]$Mode)
        if ($Mode -eq 'Light') {
            return @{
                WindowBg       = '#f0f4f8'
                PanelBg        = '#ffffff'
                PanelBorder    = '#d0d7de'
                TextPrimary    = '#0f172a'
                TextSecondary  = '#334155'
                TextMuted      = '#64748b'
                TextTitle      = '#1d4ed8'
                TextSection    = '#1e40af'
                TextAccent     = '#b45309'
                InputBg        = '#ffffff'
                InputBorder    = '#94a3b8'
                InputFg        = '#0f172a'
                CaretBrush     = '#0f172a'
                SelectionBg    = '#93c5fd'
                SelectionFg    = '#0f172a'
                BtnSecondaryBg = '#e2e8f0'
                BtnSecondaryFg = '#0f172a'
                BtnDryRunBg    = '#fef3c7'
                BtnDryRunFg    = '#92400e'
                BtnRunBg       = '#2563eb'
                BtnRunFg       = '#ffffff'
                OutputBg       = '#f8fafc'
                OutputFg       = '#334155'
                ListSelected   = '#bfdbfe'
                ListHover      = '#e2e8f0'
                HintOk         = '#15803d'
                HintWarn       = '#c2410c'
            }
        }
        return @{
            WindowBg       = '#0b0f17'
            PanelBg        = '#121826'
            PanelBorder    = '#1e293b'
            TextPrimary    = '#e2e8f0'
            TextSecondary  = '#a0aec0'
            TextMuted      = '#718096'
            TextTitle      = '#63b3ed'
            TextSection    = '#90cdf4'
            TextAccent     = '#f6ad55'
            InputBg        = '#1a1f2e'
            InputBorder    = '#2d3748'
            InputFg        = '#e2e8f0'
            CaretBrush     = '#e2e8f0'
            SelectionBg    = '#2b4c7e'
            SelectionFg    = '#ffffff'
            BtnSecondaryBg = '#2d3748'
            BtnSecondaryFg = '#e2e8f0'
            BtnDryRunBg    = '#744210'
            BtnDryRunFg    = '#faf089'
            BtnRunBg       = '#2b6cb0'
            BtnRunFg       = '#ffffff'
            OutputBg       = '#0b0f17'
            OutputFg       = '#a0aec0'
            ListSelected   = '#2b4c7e'
            ListHover      = '#232a3b'
            HintOk         = '#68d391'
            HintWarn       = '#f6ad55'
        }
    }

    function Get-ThemeToggleButtonStyle {
        param([string]$Bg, [string]$Border, [string]$HoverBg, [string]$Fg)
        $styleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       TargetType="Button">
  <Setter Property="OverridesDefaultStyle" Value="True"/>
  <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
  <Setter Property="Background" Value="$Bg"/>
  <Setter Property="BorderBrush" Value="$Border"/>
  <Setter Property="Foreground" Value="$Fg"/>
  <Setter Property="BorderThickness" Value="1"/>
  <Setter Property="Padding" Value="18,8"/>
  <Setter Property="Cursor" Value="Hand"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="Button">
        <Border x:Name="Bd" Background="$Bg"
                BorderBrush="$Border" BorderThickness="1"
                CornerRadius="17" SnapsToDevicePixels="True">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"
                            TextElement.Foreground="$Fg"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="Bd" Property="Background" Value="$HoverBg"/>
          </Trigger>
          <Trigger Property="IsPressed" Value="True">
            <Setter TargetName="Bd" Property="Background" Value="$HoverBg"/>
            <Setter TargetName="Bd" Property="Opacity" Value="0.92"/>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$styleXaml)
        return [Windows.Markup.XamlReader]::Load($reader)
    }

    function Get-SearchBoxStyle {
        param([string]$Bg, [string]$Border, [string]$Fg, [string]$Caret, [string]$SelBg, [string]$SelFg)
        $styleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       TargetType="TextBox">
  <Setter Property="OverridesDefaultStyle" Value="True"/>
  <Setter Property="Background" Value="$Bg"/>
  <Setter Property="Foreground" Value="$Fg"/>
  <Setter Property="BorderBrush" Value="$Border"/>
  <Setter Property="BorderThickness" Value="1"/>
  <Setter Property="Padding" Value="12,0"/>
  <Setter Property="VerticalContentAlignment" Value="Center"/>
  <Setter Property="CaretBrush" Value="$Caret"/>
  <Setter Property="SelectionBrush" Value="$SelBg"/>
  <Setter Property="SelectionTextBrush" Value="$SelFg"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="TextBox">
        <Border x:Name="Bd"
                Background="{TemplateBinding Background}"
                BorderBrush="{TemplateBinding BorderBrush}"
                BorderThickness="{TemplateBinding BorderThickness}"
                CornerRadius="17" SnapsToDevicePixels="True">
          <ScrollViewer x:Name="PART_ContentHost" Focusable="False"
                        HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Hidden"
                        Margin="{TemplateBinding Padding}"
                        VerticalAlignment="Center"
                        TextElement.Foreground="{TemplateBinding Foreground}"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsKeyboardFocused" Value="True">
            <Setter TargetName="Bd" Property="BorderBrush" Value="$Fg"/>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$styleXaml)
        return [Windows.Markup.XamlReader]::Load($reader)
    }

    function Update-SearchBoxStyle {
        param([hashtable]$Palette)
        # Clear local XAML values so Style setters (and our explicit sets) win
        $searchBox.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)
        $searchBox.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)
        $searchBox.ClearValue([System.Windows.Controls.Control]::BorderBrushProperty)
        $searchBox.ClearValue([System.Windows.Controls.TextBox]::CaretBrushProperty)
        $searchBox.Style = (Get-SearchBoxStyle -Bg $Palette.InputBg -Border $Palette.InputBorder -Fg $Palette.InputFg `
            -Caret $Palette.CaretBrush -SelBg $Palette.SelectionBg -SelFg $Palette.SelectionFg)
        $searchBox.Background = (ConvertTo-UiBrush $Palette.InputBg)
        $searchBox.Foreground = (ConvertTo-UiBrush $Palette.InputFg)
        $searchBox.BorderBrush = (ConvertTo-UiBrush $Palette.InputBorder)
        $searchBox.CaretBrush = (ConvertTo-UiBrush $Palette.CaretBrush)
        $searchBox.SelectionBrush = (ConvertTo-UiBrush $Palette.SelectionBg)
        try { $searchBox.SelectionTextBrush = (ConvertTo-UiBrush $Palette.SelectionFg) } catch { }
    }

    function Get-RoundedButtonStyle {
        param(
            [string]$Bg,
            [string]$Fg,
            [string]$Border,
            [string]$HoverBg,
            [int]$Radius = 10
        )
        $styleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       TargetType="Button">
  <Setter Property="OverridesDefaultStyle" Value="True"/>
  <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
  <Setter Property="Background" Value="$Bg"/>
  <Setter Property="BorderBrush" Value="$Border"/>
  <Setter Property="Foreground" Value="$Fg"/>
  <Setter Property="BorderThickness" Value="1"/>
  <Setter Property="Padding" Value="14,6"/>
  <Setter Property="Cursor" Value="Hand"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="Button">
        <Border x:Name="Bd"
                Background="{TemplateBinding Background}"
                BorderBrush="{TemplateBinding BorderBrush}"
                BorderThickness="{TemplateBinding BorderThickness}"
                CornerRadius="$Radius"
                SnapsToDevicePixels="True"
                Padding="{TemplateBinding Padding}">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"
                            TextElement.Foreground="{TemplateBinding Foreground}"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="Bd" Property="Background" Value="$HoverBg"/>
          </Trigger>
          <Trigger Property="IsPressed" Value="True">
            <Setter TargetName="Bd" Property="Background" Value="$HoverBg"/>
            <Setter TargetName="Bd" Property="Opacity" Value="0.92"/>
          </Trigger>
          <Trigger Property="IsEnabled" Value="False">
            <Setter TargetName="Bd" Property="Opacity" Value="0.45"/>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$styleXaml)
        return [Windows.Markup.XamlReader]::Load($reader)
    }

    function Update-OutputBoxStyle {
        param([hashtable]$Palette)
        if ($outputCard) {
            $outputCard.Background = (ConvertTo-UiBrush $Palette.OutputBg)
            $outputCard.BorderBrush = (ConvertTo-UiBrush $Palette.PanelBorder)
        }
        $outputBox.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)
        $outputBox.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)
        $outputBox.Background = [System.Windows.Media.Brushes]::Transparent
        $outputBox.Foreground = (ConvertTo-UiBrush $Palette.OutputFg)
        $outputBox.CaretBrush = (ConvertTo-UiBrush $Palette.CaretBrush)
        $outputBox.SelectionBrush = (ConvertTo-UiBrush $Palette.SelectionBg)
        try { $outputBox.SelectionTextBrush = (ConvertTo-UiBrush $Palette.SelectionFg) } catch { }
    }

    function Set-ThemeToggleButtonContent {
        param(
            [hashtable]$Palette,
            [ValidateSet('Dark', 'Light')][string]$Mode,
            [System.Windows.FontWeight]$LabelWeight = [System.Windows.FontWeights]::SemiBold
        )
        $showLight = ($Mode -eq 'Dark')
        $labelText = if ($showLight) { 'Light Mode' } else { 'Dark Mode' }
        $glyphChar = if ($showLight) { [char]0xE706 } else { [char]0xE708 }

        $panel = New-Object System.Windows.Controls.StackPanel
        $panel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $panel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

        $icon = New-Object System.Windows.Controls.TextBlock
        $icon.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe MDL2 Assets')
        $icon.Text = $glyphChar
        $icon.FontSize = 14
        $icon.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
        $icon.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $icon.Foreground = (ConvertTo-UiBrush $Palette.ThemeBtnFg)

        $label = New-Object System.Windows.Controls.TextBlock
        $label.Text = $labelText
        $label.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $label.FontWeight = $LabelWeight
        $label.FontSize = 13
        $label.Foreground = (ConvertTo-UiBrush $Palette.ThemeBtnFg)

        [void]$panel.Children.Add($icon)
        [void]$panel.Children.Add($label)
        $btnThemeToggle.Content = $panel
    }

    function Update-ThemeToggleButton {
        param([hashtable]$Palette, [ValidateSet('Dark', 'Light')][string]$Mode)
        if ($Mode -eq 'Light') {
            $btnBg = '#eef2f7'
            $btnBorder = '#334155'
            $btnHover = '#dde4ed'
            $textColor = '#1e293b'
            $labelWeight = [System.Windows.FontWeights]::Normal
        }
        else {
            $btnBg = $Palette.PanelBg
            $btnBorder = $Palette.InputBorder
            $btnHover = '#1a2332'
            $textColor = '#ffffff'
            $labelWeight = [System.Windows.FontWeights]::SemiBold
        }

        $btnThemeToggle.Style = (Get-ThemeToggleButtonStyle -Bg $btnBg -Border $btnBorder -HoverBg $btnHover -Fg $textColor)
        Set-ThemeToggleButtonContent -Palette @{ ThemeBtnFg = $textColor } -Mode $Mode -LabelWeight $labelWeight
    }

    function Get-ListBoxItemStyle {
        param([string]$SelectedBg, [string]$HoverBg, [string]$Fg)
        $styleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       TargetType="ListBoxItem">
  <Setter Property="Padding" Value="8,5"/>
  <Setter Property="Margin" Value="0,1"/>
  <Setter Property="Foreground" Value="$Fg"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="ListBoxItem">
        <Border x:Name="Bd" Background="Transparent" CornerRadius="8" Padding="{TemplateBinding Padding}">
          <ContentPresenter HorizontalAlignment="Stretch"
                            TextElement.Foreground="{TemplateBinding Foreground}"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsSelected" Value="True">
            <Setter TargetName="Bd" Property="Background" Value="$SelectedBg"/>
          </Trigger>
          <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="Bd" Property="Background" Value="$HoverBg"/>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$styleXaml)
        return [Windows.Markup.XamlReader]::Load($reader)
    }

    function Set-ListBoxTheme {
        param($ListBox, [hashtable]$Palette)
        $ListBox.Foreground = (ConvertTo-UiBrush $Palette.TextPrimary)
        $ListBox.Background = [System.Windows.Media.Brushes]::Transparent
        $ListBox.BorderThickness = New-Object System.Windows.Thickness(0)
        $ListBox.ItemContainerStyle = (Get-ListBoxItemStyle -SelectedBg $Palette.ListSelected -HoverBg $Palette.ListHover -Fg $Palette.TextPrimary)
    }

    function Apply-UiColorTheme {
        param([ValidateSet('Dark', 'Light')][string]$Mode)
        $script:UiColorMode = $Mode
        $p = Get-UiThemePalette -Mode $Mode

        $window.Background = (ConvertTo-UiBrush $p.WindowBg)
        $window.Foreground = (ConvertTo-UiBrush $p.TextPrimary)
        $titleText.Foreground = (ConvertTo-UiBrush $p.TextTitle)
        $subtitle.Foreground = (ConvertTo-UiBrush $p.TextMuted)
        if ($lblCopyright) { $lblCopyright.Foreground = (ConvertTo-UiBrush $p.TextMuted) }
        foreach ($panel in @($panelPlatform, $panelRole, $panelTheme, $panelCategory, $panelScripts, $panelStatus)) {
            $panel.Background = (ConvertTo-UiBrush $p.PanelBg)
            $panel.BorderBrush = (ConvertTo-UiBrush $p.PanelBorder)
            $panel.BorderThickness = New-Object System.Windows.Thickness(1)
            $panel.CornerRadius = New-Object System.Windows.CornerRadius(12)
        }
        $lblPlatform.Foreground = (ConvertTo-UiBrush $p.TextSection)
        $lblRole.Foreground = (ConvertTo-UiBrush $p.TextSection)
        $lblStatus.Foreground = (ConvertTo-UiBrush $p.TextSection)
        $lblTheme.Foreground = (ConvertTo-UiBrush $p.TextAccent)
        $lblCategory.Foreground = (ConvertTo-UiBrush $p.TextAccent)
        $lblScripts.Foreground = (ConvertTo-UiBrush $p.TextAccent)
        $legendSafeText.Foreground = (ConvertTo-UiBrush $p.TextSecondary)
        $legendCautionText.Foreground = (ConvertTo-UiBrush $p.TextSecondary)
        $legendDangerText.Foreground = (ConvertTo-UiBrush $p.TextSecondary)

        foreach ($rb in @($rbWin, $rbMac, $rbSA, $rbIT)) {
            $rb.Foreground = (ConvertTo-UiBrush $p.TextPrimary)
        }

        Update-SearchBoxStyle -Palette $p
        $lblSearch.Foreground = (ConvertTo-UiBrush $p.TextSecondary)

        Update-OutputBoxStyle -Palette $p

        $secHover = if ($Mode -eq 'Light') { '#cbd5e1' } else { '#3d4a5c' }
        $dryHover = if ($Mode -eq 'Light') { '#fde68a' } else { '#8b5a12' }
        $runHover = if ($Mode -eq 'Light') { '#1d4ed8' } else { '#3182ce' }
        $runBorder = if ($Mode -eq 'Light') { '#1e40af' } else { '#63b3ed' }

        $btnOpen.Style = (Get-RoundedButtonStyle -Bg $p.BtnSecondaryBg -Fg $p.BtnSecondaryFg -Border $p.PanelBorder -HoverBg $secHover)
        $btnOpenIse.Style = (Get-RoundedButtonStyle -Bg $p.BtnSecondaryBg -Fg $p.BtnSecondaryFg -Border $p.PanelBorder -HoverBg $secHover)
        $btnWhatIf.Style = (Get-RoundedButtonStyle -Bg $p.BtnDryRunBg -Fg $p.BtnDryRunFg -Border $p.BtnDryRunFg -HoverBg $dryHover)
        $btnRun.Style = (Get-RoundedButtonStyle -Bg $p.BtnRunBg -Fg $p.BtnRunFg -Border $runBorder -HoverBg $runHover)
        foreach ($btn in @($btnOpen, $btnOpenIse, $btnWhatIf, $btnRun)) {
            $btn.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)
            $btn.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)
            $btn.ClearValue([System.Windows.Controls.Control]::BorderBrushProperty)
            $btn.Background = (ConvertTo-UiBrush $(
                if ($btn -eq $btnWhatIf) { $p.BtnDryRunBg }
                elseif ($btn -eq $btnRun) { $p.BtnRunBg }
                else { $p.BtnSecondaryBg }
            ))
            $btn.Foreground = (ConvertTo-UiBrush $(
                if ($btn -eq $btnWhatIf) { $p.BtnDryRunFg }
                elseif ($btn -eq $btnRun) { $p.BtnRunFg }
                else { $p.BtnSecondaryFg }
            ))
        }
        Set-RunAsAdminButtonContent -Button $btnRun

        Update-ThemeToggleButton -Palette $p -Mode $Mode

        foreach ($lb in @($themeList, $categoryList, $scriptList)) {
            Set-ListBoxTheme -ListBox $lb -Palette $p
        }

        Update-RunButtons

        try { Set-Content -Path $script:UiThemePrefPath -Value $Mode -Encoding ASCII -Force } catch { }

        if ($categoryList.SelectedIndex -ge 0) {
            Refresh-ScriptList
        }
    }

    if (Test-Path $script:UiThemePrefPath) {
        $savedTheme = (Get-Content -Path $script:UiThemePrefPath -Raw -ErrorAction SilentlyContinue).Trim()
        if ($savedTheme -in @('Dark', 'Light')) { $script:UiColorMode = $savedTheme }
    }

    function Append-GuiLog([string]$msg) {
        $outputBox.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $msg))
        $outputBox.ScrollToEnd()
    }

    function Update-RunButtons {
        $isWin = ($script:Platform -eq 'Windows')
        $btnRun.IsEnabled = $isWin
        $btnWhatIf.IsEnabled = $isWin
        $p = Get-UiThemePalette -Mode $script:UiColorMode
        if ($isWin) {
            $btnRun.Opacity = 1.0
            $btnWhatIf.Opacity = 1.0
            $platformHint.Text = 'Windows scripts run elevated on this PC'
            $platformHint.Foreground = (ConvertTo-UiBrush $p.HintOk)
        } else {
            $btnRun.Opacity = 0.45
            $btnWhatIf.Opacity = 0.45
            $platformHint.Text = 'macOS scripts: browse / copy path (run on a Mac with MASTER-MENU-GUI.py)'
            $platformHint.Foreground = (ConvertTo-UiBrush $p.HintWarn)
        }
    }

    function Refresh-ThemeList {
        $themeList.Items.Clear()
        $roleName = $script:Role
        $plat = $script:Platform
        $q = if ($searchBox.Text) { $searchBox.Text.Trim().ToLowerInvariant() } else { '' }
        $pool = @($script:GuiCatalog | Where-Object { $_.Platform -eq $plat -and $_.Role -eq $roleName })
        if ($q) {
            $pool = @($pool | Where-Object {
                    $_.DisplayName.ToLowerInvariant().Contains($q) -or
                    $_.Theme.ToLowerInvariant().Contains($q) -or
                    ($_.Scripts | Where-Object { $_.BaseName.ToLowerInvariant().Contains($q) })
                })
        }
        $themes = @($pool | Select-Object -ExpandProperty Theme -Unique)
        foreach ($t in $Script:ThemeOrder) {
            if ($themes -contains $t) {
                $count = Get-SafeCount ($pool | Where-Object Theme -eq $t)
                [void]$themeList.Items.Add(("{0}  ({1})" -f $t, $count))
            }
        }
        foreach ($t in ($themes | Sort-Object)) {
            if ($Script:ThemeOrder -notcontains $t) {
                $count = Get-SafeCount ($pool | Where-Object Theme -eq $t)
                [void]$themeList.Items.Add(("{0}  ({1})" -f $t, $count))
            }
        }
        $roleLabel = if ($roleName -eq 'SysAdmin') { 'System Administrator' } else { 'IT Support' }
        $catCount = Get-SafeCount $pool
        $scriptSum = ($pool | Measure-Object -Property Count -Sum).Sum
        $scriptCount = if ($null -eq $scriptSum) { 0 } else { [int]$scriptSum }
        $subtitle.Text = ("{0} | {1} | {2} categories | {3:N0} scripts" -f $plat, $roleLabel, $catCount, $scriptCount)
        $categoryList.Items.Clear()
        $scriptList.Items.Clear()
        $script:FilteredCategories = @()
        $script:SelectedCategory = $null
        $script:SelectedScripts = @()
        if ($themeList.Items.Count -gt 0) { $themeList.SelectedIndex = 0 }
        Update-RunButtons
    }

    function Refresh-CategoryList {
        $categoryList.Items.Clear()
        $scriptList.Items.Clear()
        $script:SelectedScripts = @()
        if ($themeList.SelectedIndex -lt 0) { return }
        $themeLabel = [string]$themeList.SelectedItem
        $themeName = ($themeLabel -replace '\s+\(\d+\)$', '').Trim()
        $roleName = $script:Role
        $plat = $script:Platform
        $q = if ($searchBox.Text) { $searchBox.Text.Trim().ToLowerInvariant() } else { '' }
        $script:FilteredCategories = @($script:GuiCatalog | Where-Object {
                $_.Platform -eq $plat -and $_.Role -eq $roleName -and $_.Theme -eq $themeName
            })
        if ($q) {
            $script:FilteredCategories = @($script:FilteredCategories | Where-Object {
                    $_.DisplayName.ToLowerInvariant().Contains($q) -or
                    ($_.Scripts | Where-Object { $_.BaseName.ToLowerInvariant().Contains($q) })
                })
        }
        foreach ($c in $script:FilteredCategories) {
            [void]$categoryList.Items.Add(("{0}  ({1})" -f $c.DisplayName, $c.Count))
        }
        Append-GuiLog ("Theme: {0} ({1} categories)" -f $themeName, (Get-SafeCount $script:FilteredCategories))
        if ($categoryList.Items.Count -gt 0) { $categoryList.SelectedIndex = 0 }
    }

    function Get-RiskBrush {
        param([string]$Risk)
        $bc = [System.Windows.Media.BrushConverter]::new()
        switch ($Risk) {
            'Dangerous' { return $bc.ConvertFromString('#fc8181') }
            'Caution'   { return $bc.ConvertFromString('#ecc94b') }
            default     { return $bc.ConvertFromString('#48bb78') }
        }
    }

    function Refresh-ScriptList {
        $scriptList.Items.Clear()
        $script:SelectedScripts = @()
        if ($categoryList.SelectedIndex -lt 0) { return }
        $filteredCats = @($script:FilteredCategories)
        if ($categoryList.SelectedIndex -ge (Get-SafeCount $filteredCats)) { return }
        $script:SelectedCategory = $filteredCats[$categoryList.SelectedIndex]
        $script:SelectedScripts = @($script:SelectedCategory.Scripts)
        $q = if ($searchBox.Text) { $searchBox.Text.Trim().ToLowerInvariant() } else { '' }
        $i = 0
        $indexMap = [System.Collections.Generic.List[int]]::new()
        foreach ($s in @($script:SelectedScripts)) {
            $ui = Get-ScriptUiInfo -Path $s.FullName
            if ($q) {
                $ql = $q
                $match = $s.BaseName.ToLowerInvariant().Contains($ql) -or
                         $ui.Label.ToLowerInvariant().Contains($ql) -or
                         $ui.Risk.ToLowerInvariant().Contains($ql) -or
                         $script:SelectedCategory.DisplayName.ToLowerInvariant().Contains($ql)
                if (-not $match) { $i++; continue }
            }
            $pal = Get-UiThemePalette -Mode $script:UiColorMode
            $tipBg = if ($script:UiColorMode -eq 'Light') { '#ffffff' } else { '#1a202c' }
            $tipFg = if ($script:UiColorMode -eq 'Light') { '#0f172a' } else { '#e2e8f0' }
            $tipBorder = if ($script:UiColorMode -eq 'Light') { '#cbd5e1' } else { '#4a5568' }
            [void]$scriptList.Items.Add([pscustomobject]@{
                    Label      = $ui.Label
                    RiskBrush  = (Get-RiskBrush -Risk $ui.Risk)
                    LabelBrush = (ConvertTo-UiBrush $pal.TextPrimary)
                    InfoBrush  = (ConvertTo-UiBrush $pal.TextAccent)
                    TipBg      = (ConvertTo-UiBrush $tipBg)
                    TipFg      = (ConvertTo-UiBrush $tipFg)
                    TipBorder  = (ConvertTo-UiBrush $tipBorder)
                    InfoTip    = $ui.InfoTip
                    InfoText   = $ui.InfoText
                    Risk       = $ui.Risk
                    Care       = $ui.Care
                    FileName   = $ui.FileName
                })
            [void]$indexMap.Add($i)
            $i++
        }
        $script:ScriptIndexMap = @($indexMap)
        Append-GuiLog ("Category: {0} / {1} / {2}  ({3} scripts)" -f $script:SelectedCategory.Platform, $script:SelectedCategory.RoleLabel, $script:SelectedCategory.DisplayName, $scriptList.Items.Count)
        Append-GuiLog 'Legend: green = diagnostic  |  yellow = changes config  |  red = high impact'
    }

    function Get-SelectedScriptPath {
        if ($scriptList.SelectedIndex -lt 0) { return $null }
        $map = @($script:ScriptIndexMap)
        $scripts = @($script:SelectedScripts)
        if ((Get-SafeCount $map) -eq 0) { return $null }
        if ($scriptList.SelectedIndex -ge (Get-SafeCount $map)) {
            if ((Get-SafeCount $scripts) -gt 0 -and $scriptList.SelectedIndex -lt (Get-SafeCount $scripts)) {
                return $scripts[$scriptList.SelectedIndex].FullName
            }
            return $null
        }
        $real = $map[$scriptList.SelectedIndex]
        if ($real -ge (Get-SafeCount $scripts)) { return $null }
        return $scripts[$real].FullName
    }

    function Confirm-GuiRun([string]$Path, [switch]$WhatIf) {
        $ui = Get-ScriptUiInfo -Path $Path
        Append-GuiLog $ui.Label
        Append-GuiLog ("File: {0}" -f $ui.FileName)
        Append-GuiLog ("Risk: {0} | {1}" -f $ui.Risk, $ui.Care)
        if ($ui.Risk -eq 'Dangerous') {
            $r = [System.Windows.MessageBox]::Show(
                ("DANGEROUS`n`n{0}`n`nWarning: {1}`n`nFile: {2}`n`nAre you sure you want to continue?" -f $ui.Label, $ui.Care, $ui.FileName),
                'Dangerous script confirmation',
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning
            )
            if ($r -ne [System.Windows.MessageBoxResult]::Yes) {
                Append-GuiLog 'Run cancelled by operator.'
                return
            }
        } elseif ($ui.Risk -eq 'Caution') {
            $r = [System.Windows.MessageBox]::Show(
                ("CAUTION`n`n{0}`n`n{1}`n`nContinue?" -f $ui.Label, $ui.Care),
                'Confirmation',
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question
            )
            if ($r -ne [System.Windows.MessageBoxResult]::Yes) {
                Append-GuiLog 'Run cancelled by operator.'
                return
            }
        }
        if ($WhatIf) {
            Start-ElevatedScript -ScriptPath $Path -WhatIf
            Append-GuiLog 'Preview (Dry Run) started — no changes applied.'
        } else {
            Start-ElevatedScript -ScriptPath $Path
            Append-GuiLog 'Run started (elevated window).'
        }
    }

    $rbWin.Add_Checked({ $script:Platform = 'Windows'; Refresh-ThemeList })
    $rbMac.Add_Checked({ $script:Platform = 'macOS'; Refresh-ThemeList })
    $rbSA.Add_Checked({ $script:Role = 'SysAdmin'; Refresh-ThemeList })
    $rbIT.Add_Checked({ $script:Role = 'ITSupport'; Refresh-ThemeList })
    $themeList.Add_SelectionChanged({ Refresh-CategoryList })
    $categoryList.Add_SelectionChanged({ Refresh-ScriptList })
    $searchBox.Add_TextChanged({ Refresh-ThemeList })
    $scriptList.Add_SelectionChanged({
            $path = Get-SelectedScriptPath
            if (-not $path) { return }
            $ui = Get-ScriptUiInfo -Path $path
            Append-GuiLog '---'
            Append-GuiLog $ui.Label
            Append-GuiLog ("Warning: {0}" -f $ui.Care)
            Append-GuiLog ("File: {0}" -f $ui.FileName)
        })

    function Set-GuiWindowCentered {
        <#
        .SYNOPSIS
            Place any WPF window in the middle of the primary work area (same spot every time — no cascade).
        #>
        param(
            [Parameter(Mandatory)]$Window,
            [double]$FallbackWidth = 1360,
            [double]$FallbackHeight = 780
        )
        $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
        $wa = [System.Windows.SystemParameters]::WorkArea
        $w = $Window.Width
        $h = $Window.Height
        if ([double]::IsNaN($w) -or $w -le 0) { $w = $FallbackWidth }
        if ([double]::IsNaN($h) -or $h -le 0) { $h = $FallbackHeight }
        $Window.Left = [math]::Max($wa.X, $wa.X + (($wa.Width - $w) / 2.0))
        $Window.Top = [math]::Max($wa.Y, $wa.Y + (($wa.Height - $h) / 2.0))
        try { $Window.Activate() } catch { }
    }

    function Show-ScriptInfoDialog {
        <#
        .SYNOPSIS
            Wide, silent script briefing window (no MessageBox system sound).
        #>
        param(
            [Parameter(Mandatory)][string]$Title,
            [Parameter(Mandatory)][string]$Body,
            $Owner = $window
        )
        $pal = Get-UiThemePalette -Mode $script:UiColorMode
        $dlgXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$([System.Security.SecurityElement]::Escape($Title))"
        Width="860" Height="560" MinWidth="720" MinHeight="420"
        WindowStartupLocation="Manual" ResizeMode="CanResizeWithGrip"
        Background="$($pal.WindowBg)" Foreground="$($pal.TextPrimary)" FontFamily="Segoe UI" ShowInTaskbar="False">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock Grid.Row="0" Text="Technician briefing — read before Dry Run / Run Elevated"
               FontSize="14" FontWeight="SemiBold" Foreground="$($pal.TextTitle)" Margin="0,0,0,10" TextWrapping="Wrap"/>
    <Border Grid.Row="1" Background="$($pal.PanelBg)" BorderBrush="$($pal.PanelBorder)" BorderThickness="1" CornerRadius="10" Padding="12">
      <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
        <TextBox x:Name="BodyBox" IsReadOnly="True" TextWrapping="Wrap" BorderThickness="0"
                 Background="Transparent" Foreground="$($pal.TextPrimary)"
                 FontFamily="Consolas" FontSize="13" AcceptsReturn="True"/>
      </ScrollViewer>
    </Border>
    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
      <Button x:Name="BtnOk" Content="OK" Width="120" Height="34" IsDefault="True" Cursor="Hand"
              Background="$($pal.BtnRunBg)" Foreground="$($pal.BtnRunFg)" BorderThickness="0" FontWeight="SemiBold"/>
    </StackPanel>
  </Grid>
</Window>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$dlgXaml)
        $dlg = [Windows.Markup.XamlReader]::Load($reader)
        if ($Owner) { $dlg.Owner = $Owner }
        $bodyBox = $dlg.FindName('BodyBox')
        $btnOk = $dlg.FindName('BtnOk')
        $bodyBox.Text = $Body
        $btnOk.Add_Click({ $dlg.DialogResult = $true; $dlg.Close() })
        Set-GuiWindowCentered -Window $dlg -FallbackWidth 860 -FallbackHeight 560
        [void]$dlg.ShowDialog()
    }

    # Info (ℹ) button in SCRIPTS column — detailed what/care dialog for technicians (silent, wide)
    $scriptList.AddHandler(
        [System.Windows.Controls.Primitives.ButtonBase]::ClickEvent,
        [System.Windows.RoutedEventHandler]{
            param($sender, $e)
            $src = $e.OriginalSource
            if ($src -isnot [System.Windows.Controls.Button]) { return }
            if ([string]$src.Tag -ne 'ScriptInfo') { return }
            $e.Handled = $true
            $data = $src.DataContext
            if (-not $data) { return }
            $body = if ($data.InfoText) { [string]$data.InfoText } else { [string]$data.InfoTip }
            Show-ScriptInfoDialog -Title 'Script information' -Body $body -Owner $window
            Append-GuiLog ("Info opened: {0}" -f $data.Label)
        }
    )

    $btnThemeToggle.Add_Click({
            $next = if ($script:UiColorMode -eq 'Dark') { 'Light' } else { 'Dark' }
            Apply-UiColorTheme -Mode $next
            Append-GuiLog ("Color theme: $next")
        })

    $btnRun.Add_Click({
            $path = Get-SelectedScriptPath
            if (-not $path) { Append-GuiLog 'Select a script first.'; return }
            if ($path -like '*.sh') { Append-GuiLog 'macOS scripts cannot run on Windows.'; return }
            Confirm-GuiRun -Path $path
        })

    $btnWhatIf.Add_Click({
            $path = Get-SelectedScriptPath
            if (-not $path) { Append-GuiLog 'Select a script first.'; return }
            if ($path -like '*.sh') { Append-GuiLog 'macOS scripts cannot run on Windows.'; return }
            Confirm-GuiRun -Path $path -WhatIf
        })

    function Open-ScriptInPowerShellIse {
        param([Parameter(Mandatory)][string]$Path)
        if ($Path -notlike '*.ps1') {
            Append-GuiLog 'PowerShell ISE only opens .ps1 scripts. Select a Windows script.'
            return
        }
        if (-not (Test-Path -LiteralPath $Path)) {
            Append-GuiLog ("Script not found: {0}" -f $Path)
            return
        }
        $iseExe = Join-Path $env:Windir 'System32\WindowsPowerShell\v1.0\PowerShell_ISE.exe'
        if (-not (Test-Path -LiteralPath $iseExe)) {
            $iseCmd = Get-Command powershell_ise.exe -ErrorAction SilentlyContinue
            if ($iseCmd) { $iseExe = $iseCmd.Source }
        }
        if (-not (Test-Path -LiteralPath $iseExe)) {
            Append-GuiLog 'PowerShell ISE not found. Enable optional feature: Add-WindowsCapability -Online -Name Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0'
            return
        }

        $fullPath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).ProviderPath)
        # ISE requires one quoted file path; Start-Process -ArgumentList splits on spaces in paths
        $quotedPath = '"' + ($fullPath.Replace('"', '""')) + '"'
        $argLine = "-File $quotedPath -NoProfile"

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $iseExe
        $psi.Arguments = $argLine
        $psi.UseShellExecute = $true
        [void][System.Diagnostics.Process]::Start($psi)

        Append-GuiLog ("Opened in PowerShell ISE: {0}" -f $fullPath)
    }

    $btnOpenIse.Add_Click({
            $path = Get-SelectedScriptPath
            if (-not $path) { Append-GuiLog 'Select a script first.'; return }
            Open-ScriptInPowerShellIse -Path $path
        })

    $btnOpen.Add_Click({
            $scriptPath = Get-SelectedScriptPath
            if ($scriptPath -and (Test-Path -LiteralPath $scriptPath)) {
                # Highlight the script in Explorer without opening/executing it
                Start-Process explorer.exe -ArgumentList ("/select,`"$scriptPath`"")
                Append-GuiLog ("Selected in Explorer: {0}" -f $scriptPath)
                return
            }
            if ($script:SelectedCategory -and (Test-Path -LiteralPath $script:SelectedCategory.Path)) {
                Start-Process explorer.exe -ArgumentList $script:SelectedCategory.Path
                Append-GuiLog ("Opened folder: {0}" -f $script:SelectedCategory.Path)
            } else {
                Append-GuiLog 'Select a category or script first.'
            }
        })

    Apply-UiColorTheme -Mode $script:UiColorMode
    # Apply start-screen / CLI pre-selection (IT Repair & Diagnostic Toolkit.exe passes -Platform / -Role)
    $rbWin.IsChecked = ($script:Platform -eq 'Windows')
    $rbMac.IsChecked = ($script:Platform -eq 'macOS')
    $rbSA.IsChecked = ($script:Role -eq 'SysAdmin')
    $rbIT.IsChecked = ($script:Role -eq 'ITSupport')
    Append-GuiLog "GUI ready v$($Script:ProductVersion). Platform=$script:Platform Role=$script:Role"
    Append-GuiLog ("Catalog: {0} scripts ({1} Windows, {2} macOS) in {3} categories." -f $script:GuiStats.Total, $script:GuiStats.Windows, $script:GuiStats.Mac, $script:GuiStats.Categories)
    Refresh-ThemeList

    Set-GuiWindowCentered -Window $window -FallbackWidth 1360 -FallbackHeight 780
    [void]$window.ShowDialog()
}

# --- Main ---
try {
    if (-not (Test-Path $Script:WinRoot) -and -not (Test-Path $Script:MacRoot)) {
        Write-MenuStatus "Neither Windows nor macOS folders found under $Script:Root" -Level ERROR
        exit 2
    }
    if ($Gui) {
        Start-WpfGui
    } else {
        Start-ConsoleMenu
    }
    Write-Host ''
    Write-MenuStatus 'Master menu closed.' -Level INFO
    exit 0
} catch {
    Write-MenuStatus "FATAL: $($_.Exception.Message)" -Level ERROR
    exit 2
}
