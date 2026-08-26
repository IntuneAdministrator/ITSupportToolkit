#Requires -Version 5.1
<#
.SYNOPSIS
    Microsoft 365 cloud admin tool: Intune Config Profile Assignment Hint
.DESCRIPTION
    Phase 12 M365 tenant admin (SysAdmin/60_M365-Intune-Purview-Admin). Uses Microsoft Graph / EXO modules when installed.
    Does NOT store secrets. Prefer interactive Connect-MgGraph or existing context.
    Optional: -UserPrincipalName or env ITREPAIR_UPN for target user.
.EXAMPLE
    .\Intune-Config-Profile-Assignment-Hint.ps1 -UserPrincipalName user@contoso.com
.EXAMPLE
    .\Intune-Config-Profile-Assignment-Hint.ps1 -WhatIf
.NOTES
    Author: Allester Padovani | Version: 1.4.0 | M365 cloud (Windows)
    Elevation not required for Graph/EXO (user/admin role in tenant matters).
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [string]$UserPrincipalName,
    [bool]$OpenReport = $true,
    [switch]$SkipConnect
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$ScriptName = Split-Path $PSCommandPath -Leaf
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogDir = 'C:\IT-Logs'; $ReportDir = 'C:\IT-Logs\Reports'; $BackupDir = 'C:\IT-Logs\Backups'
New-Item -ItemType Directory -Path $LogDir,$ReportDir,$BackupDir -Force | Out-Null
$LogPath = Join-Path $LogDir ("{0}_{1}.log" -f $ScriptName, $stamp)
$ReportPath = Join-Path $ReportDir ("{0}_{1}.html" -f ($ScriptName -replace '\.ps1$',''), $stamp)
Start-Transcript -Path $LogPath -Append | Out-Null
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

function Test-ITRepairGraphModule {
    $mods = @('Microsoft.Graph.Authentication','Microsoft.Graph.Users','Microsoft.Graph.Users.Actions','Microsoft.Graph.Identity.DirectoryManagement','Microsoft.Graph.Identity.SignIns','Microsoft.Graph.Groups','Microsoft.Graph.DeviceManagement','Microsoft.Graph.Reports')
    $missing = @()
    foreach ($m in $mods) {
        if (-not (Get-Module -ListAvailable -Name $m -EA SilentlyContinue) -and -not (Get-Module -ListAvailable -Name 'Microsoft.Graph' -EA SilentlyContinue)) {
            if ($m -notin $missing) { $missing += $m }
        }
    }
    # Microsoft.Graph meta-module counts as present
    if (Get-Module -ListAvailable -Name 'Microsoft.Graph' -EA SilentlyContinue) { return ,@() }
    # Also accept Authentication alone for connect-only scripts
    if (Get-Module -ListAvailable -Name 'Microsoft.Graph.Authentication' -EA SilentlyContinue) { return ,@() }
    return ,$missing
}
function Connect-ITRepairGraph {
    param([string[]]$Scopes = @('User.Read.All','Directory.Read.All','Organization.Read.All'))
    $ctx = Get-MgContext -EA SilentlyContinue
    if ($ctx -and $ctx.Account) {
        Write-Status "Graph already connected as $($ctx.Account)" -Level SUCCESS
        Add-ReportRow -Check 'Graph context' -Result $ctx.Account -Status 'PASS' -Detail ($ctx.Scopes -join ' ')
        return $true
    }
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication -EA SilentlyContinue) -and -not (Get-Module -ListAvailable -Name Microsoft.Graph -EA SilentlyContinue)) {
        Write-Status 'Microsoft.Graph not installed. Install-Module Microsoft.Graph -Scope CurrentUser' -Level WARNING
        Add-ReportRow -Check 'Microsoft.Graph' -Result 'Missing' -Status 'WARN' -Detail 'Install-Module Microsoft.Graph -Scope CurrentUser'
        Add-ReportRow -Check 'Portal fallback' -Result 'https://admin.microsoft.com' -Status 'INFO' -Detail 'Use M365 admin center until Graph module is available'
        return $false
    }
    Import-Module Microsoft.Graph.Authentication -EA SilentlyContinue
    if ($PSCmdlet.ShouldProcess('Microsoft Graph', "Connect-MgGraph scopes=$($Scopes -join ',')")) {
        try {
            Connect-MgGraph -Scopes $Scopes -NoWelcome -EA Stop
            $ctx = Get-MgContext
            Add-ReportRow -Check 'Graph connect' -Result $(if($ctx.Account){$ctx.Account}else{'Connected'}) -Status 'PASS' -Detail ($Scopes -join ' ')
            return $true
        } catch {
            Write-Status "Graph connect failed: $($_.Exception.Message)" -Level WARNING
            Add-ReportRow -Check 'Graph connect' -Result 'Failed' -Status 'WARN' -Detail $_.Exception.Message
            return $false
        }
    }
    return $false
}
function Get-ITRepairTargetUpn {
    param([string]$Explicit)
    if ($Explicit) { return $Explicit }
    if ($env:ITREPAIR_UPN) { return $env:ITREPAIR_UPN }
    $ctx = Get-MgContext -EA SilentlyContinue
    if ($ctx -and $ctx.Account) { return $ctx.Account }
    return $null
}
function Add-M365PortalRows {
    Add-ReportRow -Check 'M365 Admin' -Result 'https://admin.microsoft.com' -Status 'INFO' -Detail ''
    Add-ReportRow -Check 'Entra Admin' -Result 'https://entra.microsoft.com' -Status 'INFO' -Detail ''
    Add-ReportRow -Check 'Exchange Admin' -Result 'https://admin.exchange.microsoft.com' -Status 'INFO' -Detail ''
    Add-ReportRow -Check 'Teams Admin' -Result 'https://admin.teams.microsoft.com' -Status 'INFO' -Detail ''
    Add-ReportRow -Check 'SharePoint Admin' -Result 'https://admin.microsoft.com/#/sharepoint' -Status 'INFO' -Detail ''
    Add-ReportRow -Check 'Intune Admin' -Result 'https://intune.microsoft.com' -Status 'INFO' -Detail ''
    Add-ReportRow -Check 'Purview' -Result 'https://purview.microsoft.com' -Status 'INFO' -Detail ''
    Add-ReportRow -Check 'Service Health' -Result 'https://admin.microsoft.com/#/servicehealth' -Status 'INFO' -Detail ''
}
Initialize-ReportState
$exitCode = 0; $Activity = 'Intune Config Profile Assignment Hint'; $totalSteps = 8; $Name = 'Intune-Config-Profile-Assignment-Hint'; $Folder = '60_M365-Intune-Purview-Admin'
$DefaultScopes = @('User.Read.All','DeviceManagementManagedDevices.Read.All','Directory.Read.All')
try {
    Write-SectionBanner 'INITIALIZATION'
    Write-ProgressStep 1 $totalSteps $Activity 'Local join-state'
    $Join = Get-JoinState
    Write-Status "Local join: $($Join.Label)" -Level INFO
    Add-ReportRow -Check 'Workstation' -Result $env:COMPUTERNAME -Status 'INFO' -Detail $Join.Label
    Add-ReportRow -Check 'Module' -Result '60_M365-Intune-Purview-Admin' -Status 'INFO' -Detail 'SysAdmin Phase12 M365'
    Add-M365PortalRows
    Write-ProgressStep 2 $totalSteps $Activity 'Graph readiness'
    $missing = Test-ITRepairGraphModule
    if ($missing.Count -gt 0 -and -not (Get-Module -ListAvailable Microsoft.Graph* -EA SilentlyContinue)) {
        Add-ReportRow -Check 'Graph modules' -Result 'Not installed' -Status 'WARN' -Detail 'Install-Module Microsoft.Graph -Scope CurrentUser'
    } else {
        Add-ReportRow -Check 'Graph modules' -Result 'Available' -Status 'PASS' -Detail ''
    }
    $connected = $false
    if (-not $SkipConnect) {
        $connected = Connect-ITRepairGraph -Scopes $DefaultScopes
    } else {
        Add-ReportRow -Check 'Graph connect' -Result 'Skipped' -Status 'INFO' -Detail '-SkipConnect'
    }
    $UPN = Get-ITRepairTargetUpn -Explicit $UserPrincipalName
    if ($UPN) { Add-ReportRow -Check 'Target UPN' -Result $UPN -Status 'INFO' -Detail '' }
    else { Add-ReportRow -Check 'Target UPN' -Result 'Not set' -Status 'WARN' -Detail 'Pass -UserPrincipalName or set ITREPAIR_UPN' }
        Write-SectionBanner 'INTUNE / PURVIEW ADMIN'
        Write-ProgressStep 3 $totalSteps $Activity 'Intune/Purview'
        Add-ReportRow -Check 'Intune' -Result 'https://intune.microsoft.com' -Status 'INFO' -Detail ''
        Add-ReportRow -Check 'Purview' -Result 'https://purview.microsoft.com' -Status 'INFO' -Detail ''
        Add-ReportRow -Check 'Secure Score' -Result 'https://security.microsoft.com/securescore' -Status 'INFO' -Detail ''
        if ($connected -and $Name -match 'Managed-Device|Compliance') {
            try {
                Import-Module Microsoft.Graph.DeviceManagement -EA SilentlyContinue
                if ($UPN) {
                    $u = Get-MgUser -UserId $UPN -EA SilentlyContinue
                    $devs = Get-MgUserManagedDevice -UserId $u.Id -EA SilentlyContinue
                    if (-not $devs) {
                        $devs = Get-MgDeviceManagementManagedDevice -Filter "userPrincipalName eq '$UPN'" -EA SilentlyContinue
                    }
                    $list = @($devs)
                    Add-ReportRow -Check 'Managed devices' -Result "$($list.Count)" -Status $(if($list.Count){'PASS'}else{'WARN'}) -Detail (($list | Select-Object -First 5 | ForEach-Object { "$($_.DeviceName):$($_.ComplianceState)" }) -join '; ')
                } else {
                    $sample = Get-MgDeviceManagementManagedDevice -Top 5 -EA SilentlyContinue
                    Add-ReportRow -Check 'Device sample' -Result "$($sample.Count)" -Status 'INFO' -Detail 'Pass -UserPrincipalName for user-scoped lookup'
                }
            } catch { Add-ReportRow -Check 'Intune Graph' -Result 'Need DeviceManagement.* scopes' -Status 'WARN' -Detail $_.Exception.Message }
        }
        if ($Name -match 'Autopilot') {
            Add-ReportRow -Check 'Autopilot' -Result 'Intune > Devices > Enrollment > Autopilot' -Status 'INFO' -Detail 'Hardware hash upload is usually OEM/ODM or Get-WindowsAutopilotInfo locally'
        }
        if ($Name -match 'Purview|DLP|Sensitivity') {
            Add-ReportRow -Check 'Labels/DLP' -Result 'Purview portal' -Status 'INFO' -Detail 'Client sees labels via Office; policy authorship is cloud-side'
        }
        if ($Name -match 'Defender-Office365') {
            Add-ReportRow -Check 'MDO' -Result 'https://security.microsoft.com' -Status 'INFO' -Detail 'Email & collaboration > Policies'
        }
        if ($Name -match 'Secure-Score') {
            if ($connected) {
                try {
                    $ss = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/security/secureScores?$top=1' -EA Stop
                    $v = @($ss.value)[0]
                    if ($v) { Add-ReportRow -Check 'Secure Score' -Result "$($v.currentScore)/$($v.maxScore)" -Status 'INFO' -Detail $v.createdDateTime }
                } catch { Add-ReportRow -Check 'Secure Score API' -Result 'Open portal' -Status 'WARN' -Detail 'Needs SecurityEvents.Read.All or similar' }
            }
        }
        Write-ProgressStep 5 $totalSteps $Activity 'Intune/Purview done'
    Write-ProgressStep $totalSteps $totalSteps $Activity 'Report'
    Export-HtmlReport -Title 'Intune Config Profile Assignment Hint' -JoinState $Join.Label -ComputerName $env:COMPUTERNAME -LogPath $LogPath -ScriptFileName $ScriptName -ReportPath $ReportPath | Out-Null
    Write-CompletionSummary -LogPath $LogPath -ReportPath $ReportPath
    if ($OpenReport) { Open-HtmlReportIfInteractive -ReportPath $ReportPath }
    $exitCode = Get-ScriptExitCode
} catch {
    Write-Status "FATAL: $($_.Exception.Message)" -Level ERROR
    try { Add-ReportRow -Check 'Fatal' -Result 'Exception' -Status 'FAIL' -Detail $_.Exception.Message; Export-HtmlReport -Title 'Intune Config Profile Assignment Hint' -JoinState 'Unknown' -ComputerName $env:COMPUTERNAME -LogPath $LogPath -ScriptFileName $ScriptName -ReportPath $ReportPath | Out-Null } catch {}
    $exitCode = 2
} finally { Write-Progress -Activity $Activity -Completed; Stop-Transcript | Out-Null }
exit $exitCode