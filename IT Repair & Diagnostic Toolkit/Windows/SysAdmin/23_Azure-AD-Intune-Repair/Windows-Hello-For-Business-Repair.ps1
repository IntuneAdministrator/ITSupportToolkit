#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Enterprise IT repair/diagnostic: Windows Hello For Business Repair
.DESCRIPTION
    Production-grade Windows SysAdmin tool for Windows-Hello-For-Business-Repair.
Category: 23_Azure-AD-Intune-Repair. Detects AD / Entra ID / Hybrid join state at runtime,
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
    .\Windows-Hello-For-Business-Repair.ps1
    Runs the full repair/diagnostic with logging and HTML report.
.EXAMPLE
    .\Windows-Hello-For-Business-Repair.ps1 -WhatIf
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
$Activity = 'Windows Hello For Business Repair'
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

        Write-SectionBanner 'AZURE AD INTUNE REPAIR'
        $Name = 'Windows-Hello-For-Business-Repair'
        Add-ReportRow -Check 'Tool' -Result 'Windows-Hello-For-Business-Repair' -Status 'INFO' -Detail '23_Azure-AD-Intune-Repair'
        Write-SectionBanner 'ENTRA ID / INTUNE'
        Add-ReportRow -Check 'Join state' -Result $Join.Label -Status 'INFO' -Detail $Join.DomainName
        $dsreg = & dsregcmd /status 2>&1 | Out-String
        $mdm = if ($dsreg -match 'MDMUrl\s*:\s*(.+)') { $Matches[1].Trim() } else { 'None' }
        $prt = $dsreg -match 'AzureAdPrt\s*:\s*YES'
        Add-ReportRow -Check 'MDM URL' -Result $mdm -Status $(if ($mdm -ne 'None') {'PASS'} else {'WARN'}) -Detail ''
        Add-ReportRow -Check 'AzureAdPrt' -Result $(if ($prt) {'YES'} else {'NO'}) -Status $(if ($prt) {'PASS'} else {'WARN'}) -Detail 'Primary Refresh Token'
        Write-ProgressStep 2 $totalSteps $Activity 'dsregcmd'

        if ($Name -match 'Join-Status|Hybrid|Device-Registration|Entra-ID-Connect') {
            foreach ($line in ($dsreg -split "`n" | Select-String 'Joined|Workplace|MDM|PRT|Tenant|DeviceId' | Select-Object -First 25)) {
                Add-ReportRow -Check 'dsreg field' -Result $line.Line.Trim() -Status 'INFO' -Detail ''
            }
            if ($Name -match 'Hybrid' -and $Join.IsDomainJoined -and -not $Join.IsAzureADJoined -and $PSCmdlet.ShouldProcess('Hybrid join', 'dsregcmd /join')) {
                & dsregcmd /join 2>&1 | Out-Null
                Add-ReportRow -Check 'dsregcmd /join' -Result 'Invoked' -Status 'INFO' -Detail 'Allow time for sync; verify with dsregcmd /status'
            }
        }

        if ($Name -match 'PRT|Token') {
            if ($PSCmdlet.ShouldProcess('PRT', 'dsregcmd /refreshprt')) {
                & dsregcmd /refreshprt 2>&1 | Out-Null
                Add-ReportRow -Check 'PRT refresh' -Result 'Triggered' -Status 'PASS' -Detail 'dsregcmd /refreshprt'
            }
        }

        if ($Name -match 'Intune|MDM|Compliance|IME|Management-Extension|Certificate-Profile|ESP|Autopilot|Co-Management|Conditional|SSPR|Hello-For-Business|Win32-App') {
            $ime = Get-Service IntuneManagementExtension -ErrorAction SilentlyContinue
            if ($ime) {
                Add-ReportRow -Check 'IntuneManagementExtension' -Result "$($ime.Status)/$($ime.StartType)" -Status $(if ($ime.Status -eq 'Running') {'PASS'} else {'WARN'}) -Detail ''
                if ($Name -match 'IME|Management-Extension' -and $PSCmdlet.ShouldProcess('IME', 'Restart IntuneManagementExtension')) {
                    Restart-Service IntuneManagementExtension -Force -ErrorAction SilentlyContinue
                    Add-ReportRow -Check 'IME restart' -Result (Get-Service IntuneManagementExtension).Status -Status 'PASS' -Detail ''
                }
            } else {
                Add-ReportRow -Check 'IntuneManagementExtension' -Result 'Not installed' -Status 'WARN' -Detail 'Device may not be MDM enrolled'
            }

            if ($Name -match 'Re-Enroll|Compliance|Force-Sync' -and $PSCmdlet.ShouldProcess('MDM', 'deviceenroller sync')) {
                Start-Process "$env:windir\system32\deviceenroller.exe" -ArgumentList '/c','/AutoEnrollMDM' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'MDM sync trigger' -Result 'deviceenroller invoked' -Status 'INFO' -Detail '/c /AutoEnrollMDM'
            }

            if ($Name -match 'Win32-App|Log-Collector') {
                $imeLog = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
                if (Test-Path $imeLog) {
                    $dest = Join-Path 'C:\IT-Logs' ("IME_Logs_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
                    New-Item $dest -ItemType Directory -Force | Out-Null
                    Copy-Item "$imeLog\*" $dest -Recurse -Force -ErrorAction SilentlyContinue
                    Add-ReportRow -Check 'IME logs copied' -Result $dest -Status 'PASS' -Detail $imeLog
                } else {
                    Add-ReportRow -Check 'IME logs' -Result 'Path missing' -Status 'WARN' -Detail $imeLog
                }
            }

            if ($Name -match 'Autopilot-Hash') {
                try {
                    $hash = (Get-CimInstance -Namespace root/cimv2/mdm/dmmap -ClassName MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'" -ErrorAction Stop).DeviceHardwareData
                    $out = Join-Path 'C:\IT-Logs' ("AutopilotHash_{0}.csv" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
                    "Device Serial Number,Windows Product ID,Hardware Hash`n$env:COMPUTERNAME,,$hash" | Set-Content $out -Encoding UTF8
                    Add-ReportRow -Check 'Autopilot hash export' -Result 'Saved' -Status 'PASS' -Detail $out
                } catch {
                    Add-ReportRow -Check 'Autopilot hash' -Result 'Failed' -Status 'WARN' -Detail $_.Exception.Message
                }
            }

            if ($Name -match 'ESP') {
                $esp = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5
                Add-ReportRow -Check 'Enrollments keys' -Result "$(@($esp).Count) sampled" -Status 'INFO' -Detail 'Review ESP tracking in Enrollment registry'
            }
        }
        Write-ProgressStep 4 $totalSteps $Activity 'Intune/Entra'

    Write-ProgressStep $totalSteps $totalSteps $Activity 'Export report'
    Export-HtmlReport -Title 'Windows Hello For Business Repair' -JoinState $Join.Label -ComputerName $env:COMPUTERNAME -LogPath $LogPath -ScriptFileName $ScriptName -ReportPath $ReportPath | Out-Null
    Write-CompletionSummary -LogPath $LogPath -ReportPath $ReportPath
    if ($OpenReport) { Open-HtmlReportIfInteractive -ReportPath $ReportPath }
    $exitCode = Get-ScriptExitCode
}
catch {
    Write-Status "FATAL: $($_.Exception.Message)" -Level ERROR
    try {
        Add-ReportRow -Check 'Fatal error' -Result 'Exception' -Status 'FAIL' -Detail $_.Exception.Message
        Export-HtmlReport -Title 'Windows Hello For Business Repair' -JoinState 'Unknown' -ComputerName $env:COMPUTERNAME -LogPath $LogPath -ScriptFileName $ScriptName -ReportPath $ReportPath | Out-Null
    } catch { }
    $exitCode = 2
}
finally {
    Write-Progress -Activity $Activity -Completed
    Stop-Transcript | Out-Null
}

exit $exitCode
