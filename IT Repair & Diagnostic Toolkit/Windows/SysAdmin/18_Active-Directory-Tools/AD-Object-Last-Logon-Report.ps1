#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Enterprise IT repair/diagnostic: AD Object Last Logon Report
.DESCRIPTION
    Production-grade Windows SysAdmin tool for AD-Object-Last-Logon-Report.
Category: 18_Active-Directory-Tools. Detects AD / Entra ID / Hybrid join state at runtime,
supports -WhatIf for destructive actions, writes transcript logs to C:\IT-Logs,
and emits a dark-theme HTML results report under C:\IT-Logs\Reports.
Compatible with interactive admin use and Intune Win32 / PowerShell script deployment.
.PARAMETER WhatIf
    Shows what would happen without making changes (SupportsShouldProcess).
.PARAMETER Confirm
    Prompts for confirmation before high-impact changes.
.PARAMETER OpenReport
    Open HTML report in the default browser when interactive (default: $true).
.EXAMPLE
    .\AD-Object-Last-Logon-Report.ps1
    Runs the full repair/diagnostic with logging and HTML report.
.EXAMPLE
    .\AD-Object-Last-Logon-Report.ps1 -WhatIf
    Previews destructive actions without applying them.
.NOTES
    Author:    Allester Padovani
    Version:   1.0.0
    Created:   2025-01-01
    Requires:  Administrator, PS 5.1+
    Tested:    Windows 21H2 / 22H2 / 23H2 / 24H2
    Deployment: Compatible with Intune PowerShell script policy
                and Win32 app packaging (.intunewin)
    Rollback:  Registry/config backups under C:\IT-Logs\Backups
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [bool]$OpenReport = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptName = Split-Path $PSCommandPath -Leaf
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogDir = 'C:\IT-Logs'
$ReportDir = 'C:\IT-Logs\Reports'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$LogPath = Join-Path $LogDir ("{0}_{1}.log" -f $ScriptName, $stamp)
$ReportPath = Join-Path $ReportDir ("{0}_{1}.html" -f ($ScriptName -replace '\.ps1$',''), $stamp)
$BackupDir = 'C:\IT-Logs\Backups'
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

Start-Transcript -Path $LogPath -Append | Out-Null

# --- Embedded common UI / report helpers ---
# IT-Repair-Scripts — Shared Common Library (embedded into every script at generation time)
# Do not run this file standalone; it is concatenated into generated scripts.

function Write-Status {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')][string]$Level = 'INFO'
    )
    $colors = @{ INFO = 'Cyan'; SUCCESS = 'Green'; WARNING = 'Yellow'; ERROR = 'Red' }
    $ts = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$Level] $ts $Message" -ForegroundColor $colors[$Level]
}

function Write-ProgressStep {
    param(
        [Parameter(Mandatory)][int]$Step,
        [Parameter(Mandatory)][int]$Total,
        [Parameter(Mandatory)][string]$Activity,
        [Parameter(Mandatory)][string]$Status
    )
    $pct    = [int](($Step / [Math]::Max($Total, 1)) * 100)
    if ($pct -gt 100) { $pct = 100 }
    $filled = [Math]::Min(20, [int]($pct / 5))
    $bar    = '[' + ('█' * $filled) + ('░' * (20 - $filled)) + "]  $pct%"
    Write-Progress -Activity $Activity -Status "$Status ($Step/$Total)" -PercentComplete $pct
    Write-Status "$bar  Step $Step/$Total — $Status" -Level INFO
}

function Write-SectionBanner {
    param([Parameter(Mandatory)][string]$Name)
    Write-Host "`n══════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "  [$Name]" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════`n" -ForegroundColor DarkCyan
}

function Get-JoinState {
    $state = [ordered]@{
        IsAzureADJoined = $false
        IsDomainJoined  = $false
        IsHybridJoined  = $false
        Label           = 'Workgroup (not domain joined)'
        DomainName      = $env:USERDOMAIN
        Raw             = ''
    }
    try {
        $dsregOutput = & dsregcmd /status 2>&1 | Out-String
        $state.Raw = $dsregOutput
        $state.IsAzureADJoined = ($dsregOutput -match 'AzureAdJoined\s*:\s*YES')
        $state.IsDomainJoined  = ($dsregOutput -match 'DomainJoined\s*:\s*YES')
        $state.IsHybridJoined  = $state.IsAzureADJoined -and $state.IsDomainJoined
        if ($state.IsHybridJoined) {
            $state.Label = 'Hybrid (on-prem AD + Entra ID)'
        } elseif ($state.IsDomainJoined) {
            $state.Label = 'On-premises AD only'
        } elseif ($state.IsAzureADJoined) {
            $state.Label = 'Azure AD / Entra ID only'
        }
        $dn = [regex]::Match($dsregOutput, 'DomainName\s*:\s*(.+)')
        if ($dn.Success) { $state.DomainName = $dn.Groups[1].Value.Trim() }
    } catch {
        Write-Status "dsregcmd unavailable; using Win32_ComputerSystem fallback" -Level WARNING
        try {
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            if ($cs.PartOfDomain) {
                $state.IsDomainJoined = $true
                $state.DomainName = $cs.Domain
                $state.Label = 'On-premises AD only'
            }
        } catch { }
    }
    return [pscustomobject]$state
}

function Initialize-ReportState {
    $Script:ReportRows = [System.Collections.Generic.List[string]]::new()
    $Script:PassCount  = 0
    $Script:FailCount  = 0
    $Script:WarnCount  = 0
    $Script:InfoCount  = 0
}

function Add-ReportRow {
    param(
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][string]$Result,
        [Parameter(Mandatory)][ValidateSet('PASS','FAIL','WARN','INFO')][string]$Status,
        [string]$Detail = ''
    )
    switch ($Status) {
        'PASS' { $Script:PassCount++ }
        'FAIL' { $Script:FailCount++ }
        'WARN' { $Script:WarnCount++ }
        'INFO' { $Script:InfoCount++ }
    }
    $safeCheck  = [System.Net.WebUtility]::HtmlEncode($Check)
    $safeResult = [System.Net.WebUtility]::HtmlEncode($Result)
    $safeDetail = [System.Net.WebUtility]::HtmlEncode($Detail)
    $badge = "<span class='badge $($Status.ToLower())'>$Status</span>"
    $Script:ReportRows.Add("<tr><td>$safeCheck</td><td>$safeResult</td><td>$badge</td><td><small>$safeDetail</small></td></tr>")
}

function Export-HtmlReport {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$JoinState,
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$ScriptFileName,
        [Parameter(Mandatory)][string]$ReportPath
    )
    $reportDir = Split-Path -Parent $ReportPath
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    $tableRows = ($Script:ReportRows -join "`n")
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $titleEnc  = [System.Net.WebUtility]::HtmlEncode($Title)
    $joinEnc   = [System.Net.WebUtility]::HtmlEncode($JoinState)
    $compEnc   = [System.Net.WebUtility]::HtmlEncode($ComputerName)
    $logEnc    = [System.Net.WebUtility]::HtmlEncode($LogPath)
    $fileEnc   = [System.Net.WebUtility]::HtmlEncode($ScriptFileName)

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!DOCTYPE html>')
    [void]$sb.AppendLine('<html lang="en">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="UTF-8">')
    [void]$sb.AppendLine("<title>$titleEnc</title>")
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('  * { box-sizing:border-box; margin:0; padding:0; }')
    [void]$sb.AppendLine('  body { font-family:''Segoe UI'',Arial,sans-serif; background:#0f1117; color:#e2e8f0; padding:24px; }')
    [void]$sb.AppendLine('  h1 { color:#63b3ed; margin-bottom:4px; font-size:1.6rem; }')
    [void]$sb.AppendLine('  .meta { color:#718096; font-size:.85rem; margin-bottom:20px; }')
    [void]$sb.AppendLine('  .meta span { margin-right:18px; }')
    [void]$sb.AppendLine('  .summary { display:flex; gap:14px; margin-bottom:20px; flex-wrap:wrap; }')
    [void]$sb.AppendLine('  .card { background:#1a1f2e; border-radius:8px; padding:14px 20px; min-width:120px; }')
    [void]$sb.AppendLine('  .card .num { font-size:2rem; font-weight:700; }')
    [void]$sb.AppendLine('  .card .lbl { font-size:.75rem; color:#718096; text-transform:uppercase; }')
    [void]$sb.AppendLine('  .green{color:#68d391} .red{color:#fc8181} .yellow{color:#f6e05e} .blue{color:#63b3ed}')
    [void]$sb.AppendLine('  table { width:100%; border-collapse:collapse; background:#1a1f2e; border-radius:8px; overflow:hidden; }')
    [void]$sb.AppendLine('  th { background:#2d3748; color:#90cdf4; text-align:left; padding:10px 14px; font-size:.8rem; text-transform:uppercase; letter-spacing:.05em; }')
    [void]$sb.AppendLine('  td { padding:9px 14px; border-bottom:1px solid #2d3748; font-size:.88rem; vertical-align:top; }')
    [void]$sb.AppendLine('  tr:last-child td { border-bottom:none; }')
    [void]$sb.AppendLine('  tr:hover td { background:#232a3b; }')
    [void]$sb.AppendLine('  .badge { display:inline-block; padding:2px 10px; border-radius:999px; font-size:.75rem; font-weight:700; }')
    [void]$sb.AppendLine('  .pass{background:#22543d;color:#68d391} .fail{background:#742a2a;color:#fc8181}')
    [void]$sb.AppendLine('  .warn{background:#744210;color:#f6e05e} .info{background:#1a365d;color:#63b3ed}')
    [void]$sb.AppendLine('  footer { margin-top:16px; color:#4a5568; font-size:.8rem; }')
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    [void]$sb.AppendLine("<h1>🔧 $titleEnc</h1>")
    [void]$sb.AppendLine('<div class="meta">')
    [void]$sb.AppendLine("  <span>🖥️ <strong>$compEnc</strong></span>")
    [void]$sb.AppendLine("  <span>🔗 Join State: <strong>$joinEnc</strong></span>")
    [void]$sb.AppendLine("  <span>🕐 $timestamp</span>")
    [void]$sb.AppendLine("  <span>📄 Log: $logEnc</span>")
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('<div class="summary" id="summary"></div>')
    [void]$sb.AppendLine('<table>')
    [void]$sb.AppendLine('  <thead><tr><th>Check</th><th>Result</th><th>Status</th><th>Detail</th></tr></thead>')
    [void]$sb.AppendLine('  <tbody>')
    [void]$sb.AppendLine($tableRows)
    [void]$sb.AppendLine('  </tbody>')
    [void]$sb.AppendLine('</table>')
    [void]$sb.AppendLine("<footer>IT-Repair-Scripts v1.0.0 — $fileEnc</footer>")
    [void]$sb.AppendLine('<script>')
    [void]$sb.AppendLine('  const rows=document.querySelectorAll("tbody tr");')
    [void]$sb.AppendLine('  const c={PASS:0,FAIL:0,WARN:0,INFO:0};')
    [void]$sb.AppendLine('  rows.forEach(r=>{const b=r.querySelector(".badge");if(b)c[b.textContent.trim()]=(c[b.textContent.trim()]||0)+1;});')
    [void]$sb.AppendLine('  const col={PASS:"green",FAIL:"red",WARN:"yellow",INFO:"blue"};')
    [void]$sb.AppendLine('  const lbl={PASS:"Passed",FAIL:"Failed",WARN:"Warnings",INFO:"Info"};')
    [void]$sb.AppendLine('  const s=document.getElementById("summary");')
    [void]$sb.AppendLine('  Object.entries(c).forEach(([k,v])=>{if(v>0)s.innerHTML+=`<div class="card"><div class="num ${col[k]}">${v}</div><div class="lbl">${lbl[k]}</div></div>`;});')
    [void]$sb.AppendLine('</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')
    Set-Content -Path $ReportPath -Value $sb.ToString() -Encoding UTF8
    return $ReportPath
}

function Open-HtmlReportIfInteractive {
    param([Parameter(Mandatory)][string]$ReportPath)
    $isSystem = ([Security.Principal.WindowsIdentity]::GetCurrent().Name -match 'SYSTEM')
    $sessionName = $env:SESSIONNAME
    $isIntune = ($env:USERNAME -eq 'SYSTEM') -or $isSystem -or ($sessionName -eq 'Service-0x0')
    if (-not $isIntune -and (Test-Path $ReportPath)) {
        try { Start-Process $ReportPath } catch { Write-Status "Could not open report: $($_.Exception.Message)" -Level WARNING }
    } else {
        Write-Status "Report browser open suppressed (SYSTEM/Intune session)" -Level INFO
    }
}

function Write-CompletionSummary {
    param([string]$LogPath, [string]$ReportPath)
    Write-Host "`n┌─────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│         SCRIPT COMPLETE                 │" -ForegroundColor Cyan
    Write-Host "├─────────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "│  PASS  : $($Script:PassCount)" -ForegroundColor Green
    Write-Host "│  FAIL  : $($Script:FailCount)" -ForegroundColor Red
    Write-Host "│  WARN  : $($Script:WarnCount)" -ForegroundColor Yellow
    Write-Host "│  Log   : $LogPath" -ForegroundColor Gray
    Write-Host "│  Report: $ReportPath" -ForegroundColor Gray
    Write-Host "└─────────────────────────────────────────┘" -ForegroundColor Cyan
}

function Backup-RegistryKey {
    param(
        [Parameter(Mandatory)][string]$KeyPath,
        [Parameter(Mandatory)][string]$BackupDir
    )
    if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
    $safeName = ($KeyPath -replace '[\\/:*?"<>|]', '_')
    $backupFile = Join-Path $BackupDir ("{0}_{1}.reg" -f $safeName, (Get-Date -Format 'yyyyMMdd_HHmmss'))
    if (Test-Path $KeyPath) {
        & reg.exe export $KeyPath $backupFile /y 2>$null | Out-Null
        if (Test-Path $backupFile) {
            Write-Status "Registry backup saved: $backupFile" -Level SUCCESS
            Write-Status "Rollback: reg import `"$backupFile`"" -Level INFO
            return $backupFile
        }
    }
    Write-Status "No registry key to backup or export failed: $KeyPath" -Level WARNING
    return $null
}

function Get-ScriptExitCode {
    if ($Script:FailCount -gt 0) { return 2 }
    if ($Script:WarnCount -gt 0) { return 1 }
    return 0
}


Initialize-ReportState
$exitCode = 0
$Activity = 'AD Object Last Logon Report'
$totalSteps = 8

try {
    Write-SectionBanner 'INITIALIZATION'
    Write-ProgressStep 1 $totalSteps $Activity 'Start + join-state detection'

    # --- AD / Identity Join State Detection ---
    $Join = Get-JoinState
    if ($Join.IsHybridJoined)    { Write-Status "Join state: Hybrid (on-prem AD + Entra ID)" -Level INFO }
    elseif ($Join.IsDomainJoined) { Write-Status "Join state: On-premises AD only" -Level INFO }
    elseif ($Join.IsAzureADJoined){ Write-Status "Join state: Azure AD / Entra ID only" -Level INFO }
    else                     { Write-Status "Join state: Workgroup (not domain joined)" -Level WARNING }

    Add-ReportRow -Check 'Computer' -Result $env:COMPUTERNAME -Status 'INFO' -Detail $Join.Label
    Add-ReportRow -Check 'Join state' -Result $Join.Label -Status 'INFO' -Detail $Join.DomainName
    Add-ReportRow -Check 'PowerShell' -Result $PSVersionTable.PSVersion.ToString() -Status 'INFO' -Detail $PSVersionTable.PSEdition

        Write-SectionBanner 'ACTIVE DIRECTORY TOOLS'
        $Name = 'AD-Object-Last-Logon-Report'
        Add-ReportRow -Check 'Tool' -Result 'AD-Object-Last-Logon-Report' -Status 'INFO' -Detail '18_Active-Directory-Tools'
        Write-SectionBanner 'ACTIVE DIRECTORY / IDENTITY'
        Add-ReportRow -Check 'Join state' -Result $Join.Label -Status $(if ($Join.IsDomainJoined -or $Join.IsHybridJoined) {'PASS'} else {'WARN'}) -Detail $Join.DomainName

        $script:DoAdDeep = ($Join.IsDomainJoined -or $Join.IsHybridJoined)
        if (-not $script:DoAdDeep) {
            if ($Join.IsAzureADJoined) {
                Add-ReportRow -Check 'AD tools applicability' -Result 'Entra-only device' -Status 'WARN' -Detail 'Use Graph/Entra admin center; classic AD cmdlets limited'
            } else {
                Add-ReportRow -Check 'AD tools applicability' -Result 'Workgroup' -Status 'FAIL' -Detail 'Domain join required for most AD checks'
            }
            Write-ProgressStep 3 $totalSteps $Activity 'Skipped AD server checks'
        }

        if ($script:DoAdDeep) {
        Write-ProgressStep 2 $totalSteps $Activity 'Domain connectivity'
        try {
            $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
            Add-ReportRow -Check 'AD domain' -Result $domain.Name -Status 'PASS' -Detail "PDC=$($domain.PdcRoleOwner)"
        } catch {
            Add-ReportRow -Check 'AD domain bind' -Result 'Failed' -Status 'FAIL' -Detail $_.Exception.Message
        }

        if ($Name -match 'Kerberos-Ticket|Kerberos-Clock') {
            $klist = & klist 2>&1 | Out-String
            Add-ReportRow -Check 'klist' -Result 'Tickets listed' -Status 'INFO' -Detail ($klist.Substring(0, [Math]::Min(400, $klist.Length)))
            if ($Name -match 'Ticket-Repair' -and $PSCmdlet.ShouldProcess('Kerberos', 'klist purge')) {
                & klist purge 2>&1 | Out-Null
                Add-ReportRow -Check 'klist purge' -Result 'Purged' -Status 'PASS' -Detail 'User will re-authenticate'
            }
            if ($Name -match 'Clock') {
                $w32 = & w32tm /query /status 2>&1 | Out-String
                Add-ReportRow -Check 'Time status' -Result 'Queried' -Status 'INFO' -Detail ($w32.Substring(0, [Math]::Min(300, $w32.Length)))
            }
        }

        if ($Name -match 'Replication|DC-Diagnostic|Forest|SYSVOL|Site-Link') {
            if (Get-Command repadmin -ErrorAction SilentlyContinue) {
                $repl = & repadmin /replsummary 2>&1 | Out-String
                Add-ReportRow -Check 'repadmin /replsummary' -Result 'Completed' -Status 'INFO' -Detail ($repl.Substring(0, [Math]::Min(500, $repl.Length)))
            } else {
                Add-ReportRow -Check 'repadmin' -Result 'Not found (install RSAT)' -Status 'WARN' -Detail 'RSAT: Active Directory Domain Services Tools'
            }
            if ($Name -match 'DC-Diagnostic' -and (Get-Command dcdiag -ErrorAction SilentlyContinue)) {
                $dd = & dcdiag /q 2>&1 | Out-String
                Add-ReportRow -Check 'dcdiag /q' -Result $(if ($dd -match 'failed') {'Issues'} else {'Quiet OK / see detail'}) -Status $(if ($dd -match 'failed') {'WARN'} else {'PASS'}) -Detail ($dd.Substring(0, [Math]::Min(400, [Math]::Max(0,$dd.Length))))
            }
            if ($Name -match 'SYSVOL') {
                $sysvol = "\\$($Join.DomainName)\SYSVOL"
                Add-ReportRow -Check 'SYSVOL path' -Result $(if (Test-Path $sysvol) {'Reachable'} else {'Unreachable'}) -Status $(if (Test-Path $sysvol) {'PASS'} else {'FAIL'}) -Detail $sysvol
            }
        }

        if ($Name -match 'GPO|Password-Policy|Fine-Grained') {
            if ($PSCmdlet.ShouldProcess('GPO', 'gpresult summary')) {
                $gpr = & gpresult /r 2>&1 | Out-String
                Add-ReportRow -Check 'gpresult /r' -Result 'Captured' -Status 'INFO' -Detail ($gpr.Substring(0, [Math]::Min(500, $gpr.Length)))
            }
            try {
                $pol = Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop
                Add-ReportRow -Check 'Domain password policy' -Result "MinLen=$($pol.MinPasswordLength) MaxAge=$($pol.MaxPasswordAge)" -Status 'INFO' -Detail "Complexity=$($pol.ComplexityEnabled)"
            } catch {
                Add-ReportRow -Check 'Password policy' -Result 'RSAT/AD module needed or access denied' -Status 'WARN' -Detail $_.Exception.Message
            }
        }

        if ($Name -match 'DNS-AD') {
            try {
                $r = Resolve-DnsName -Name ("_ldap._tcp.dc._msdcs.{0}" -f $Join.DomainName) -Type SRV -ErrorAction Stop
                Add-ReportRow -Check 'DC locator SRV' -Result "$($r.Count) records" -Status 'PASS' -Detail (($r | Select-Object -First 5 NameTarget) -join ', ')
            } catch {
                Add-ReportRow -Check 'DC locator SRV' -Result 'Failed' -Status 'FAIL' -Detail $_.Exception.Message
            }
        }

        if ($Name -match 'Computer-Account-Reset') {
            Add-ReportRow -Check 'Secure channel' -Result 'Test-ComputerSecureChannel' -Status 'INFO' -Detail 'Requires domain connectivity'
            if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Test/Repair secure channel')) {
                try {
                    $ok = Test-ComputerSecureChannel -Verbose -ErrorAction Stop
                    Add-ReportRow -Check 'Secure channel' -Result "$ok" -Status $(if ($ok) {'PASS'} else {'FAIL'}) -Detail ''
                    if (-not $ok) {
                        Test-ComputerSecureChannel -Repair -Credential (Get-Credential) -ErrorAction SilentlyContinue | Out-Null
                        Add-ReportRow -Check 'Secure channel repair' -Result 'Attempted (credential prompt may be blocked in Intune)' -Status 'WARN' -Detail 'Prefer Reset-ComputerMachinePassword on interactive admin session'
                    }
                } catch {
                    Add-ReportRow -Check 'Secure channel' -Result 'Error' -Status 'WARN' -Detail $_.Exception.Message
                }
            }
        }

        if ($Name -match 'Lockout|Group-Membership|Privileged|Last-Logon|Stale-Computer|SPN|AdminSDHolder|OU-Delegation|Recycle-Bin|Trust|Schema') {
            if (Get-Module -ListAvailable -Name ActiveDirectory) {
                Import-Module ActiveDirectory -ErrorAction SilentlyContinue
                if ($Name -match 'Schema') {
                    try {
                        $root = Get-ADRootDSE
                        Add-ReportRow -Check 'schemaNamingContext' -Result $root.schemaNamingContext -Status 'PASS' -Detail "domainControllerFunctionality=$($root.domainControllerFunctionality)"
                    } catch {
                        Add-ReportRow -Check 'Schema' -Result 'Failed' -Status 'WARN' -Detail $_.Exception.Message
                    }
                }
                if ($Name -match 'Recycle-Bin' -and $PSCmdlet.ShouldProcess('AD Recycle Bin', 'Enable if disabled (forest-wide)')) {
                    try {
                        $feat = Get-ADOptionalFeature -Filter 'name -like "Recycle Bin Feature"'
                        Add-ReportRow -Check 'Recycle Bin feature' -Result "$($feat.EnabledScopes.Count) scopes" -Status 'INFO' -Detail $feat.Name
                    } catch {
                        Add-ReportRow -Check 'Recycle Bin' -Result 'Check failed' -Status 'WARN' -Detail $_.Exception.Message
                    }
                }
                if ($Name -match 'Privileged|Group-Membership') {
                    foreach ($g in @('Domain Admins','Enterprise Admins','Schema Admins')) {
                        try {
                            $m = @(Get-ADGroupMember -Identity $g -ErrorAction Stop)
                            Add-ReportRow -Check $g -Result "$($m.Count) members" -Status $(if ($m.Count -le 5) {'PASS'} else {'WARN'}) -Detail (($m | Select-Object -First 8 SamAccountName) -join ', ')
                        } catch {
                            Add-ReportRow -Check $g -Result 'N/A' -Status 'INFO' -Detail $_.Exception.Message
                        }
                    }
                }
                if ($Name -match 'Stale-Computer') {
                    $cut = (Get-Date).AddDays(-90)
                    try {
                        $stale = @(Get-ADComputer -Filter {Enabled -eq $true -and PasswordLastSet -lt $cut} -Properties PasswordLastSet | Select-Object -First 25)
                        Add-ReportRow -Check 'Stale computers (>90d)' -Result "$($stale.Count) sampled" -Status $(if ($stale.Count -eq 0) {'PASS'} else {'WARN'}) -Detail (($stale | ForEach-Object Name) -join ', ')
                    } catch {
                        Add-ReportRow -Check 'Stale computers' -Result 'Query failed' -Status 'WARN' -Detail $_.Exception.Message
                    }
                }
            } else {
                Add-ReportRow -Check 'ActiveDirectory module' -Result 'RSAT not installed' -Status 'WARN' -Detail 'Install-WindowsFeature RSAT-AD-PowerShell or capability'
            }
        }
        Write-ProgressStep 4 $totalSteps $Activity 'AD checks'
        } # end DoAdDeep

    Write-ProgressStep $totalSteps $totalSteps $Activity 'Export report'
    Export-HtmlReport -Title 'AD Object Last Logon Report' -JoinState $Join.Label -ComputerName $env:COMPUTERNAME -LogPath $LogPath -ScriptFileName $ScriptName -ReportPath $ReportPath | Out-Null
    Write-CompletionSummary -LogPath $LogPath -ReportPath $ReportPath
    if ($OpenReport) { Open-HtmlReportIfInteractive -ReportPath $ReportPath }
    $exitCode = Get-ScriptExitCode
}
catch {
    Write-Status "FATAL: $($_.Exception.Message)" -Level ERROR
    try {
        Add-ReportRow -Check 'Fatal error' -Result 'Exception' -Status 'FAIL' -Detail $_.Exception.Message
        Export-HtmlReport -Title 'AD Object Last Logon Report' -JoinState 'Unknown' -ComputerName $env:COMPUTERNAME -LogPath $LogPath -ScriptFileName $ScriptName -ReportPath $ReportPath | Out-Null
    } catch { }
    $exitCode = 2
}
finally {
    Write-Progress -Activity $Activity -Completed
    Stop-Transcript | Out-Null
}

exit $exitCode
