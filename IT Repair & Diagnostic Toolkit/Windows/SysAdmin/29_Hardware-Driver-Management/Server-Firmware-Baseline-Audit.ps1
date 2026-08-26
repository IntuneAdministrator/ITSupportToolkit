#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Common problem fix: Server Firmware Baseline Audit
.DESCRIPTION
    Phase 13 common-problems module (SysAdmin / 29_Hardware-Driver-Management). Join-state aware, Intune-compatible,
    transcript log + dark HTML report. Use -WhatIf to preview changes.
.EXAMPLE
    .\Server-Firmware-Baseline-Audit.ps1
.EXAMPLE
    .\Server-Firmware-Baseline-Audit.ps1 -WhatIf
.NOTES
    Author: Allester Padovani
    IT Repair & Diagnostic Toolkit | Version 1.5.1 | Windows 21H2-24H2
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param([bool]$OpenReport = $true)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ScriptName = Split-Path $PSCommandPath -Leaf
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogDir = 'C:\IT-Logs'; $ReportDir = 'C:\IT-Logs\Reports'; $BackupDir = 'C:\IT-Logs\Backups'
New-Item -ItemType Directory -Path $LogDir, $ReportDir, $BackupDir -Force | Out-Null
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

Initialize-ReportState
$exitCode = 0; $Activity = 'Server Firmware Baseline Audit'; $totalSteps = 8; $Name = 'Server-Firmware-Baseline-Audit'
try {
    Write-SectionBanner 'INITIALIZATION'
    Write-ProgressStep 1 $totalSteps $Activity 'Join-state detection'
    $Join = Get-JoinState
    Write-Status "Join state: $($Join.Label)" -Level INFO
    Add-ReportRow -Check 'Computer' -Result $env:COMPUTERNAME -Status 'INFO' -Detail $Join.Label
    Add-ReportRow -Check 'Module' -Result '29_Hardware-Driver-Management' -Status 'INFO' -Detail 'SysAdmin'
        Write-SectionBanner 'COMMON PROBLEM TRIAGE'
        Write-ProgressStep 2 $totalSteps $Activity 'Environment snapshot'
        Add-ReportRow -Check 'User' -Result $env:USERNAME -Status 'INFO' -Detail $env:USERPROFILE
        Add-ReportRow -Check 'OS' -Result (Get-CimInstance Win32_OperatingSystem).Caption -Status 'INFO' -Detail (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion

        if ($Name -match 'Clipboard|Snipping|Search|Sticky|Night-Light|Touchpad|Num-Lock|Widgets|Taskbar|Action-Center|Focus') {
            Write-ProgressStep 3 $totalSteps $Activity 'Shell / UX repair'
            if ($Name -match 'Clipboard' -and $PSCmdlet.ShouldProcess('Clipboard', 'Reset Cloud Clipboard + history')) {
                Stop-Process -Name ctfmon -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 1
                Start-Process ctfmon
                Add-ReportRow -Check 'Clipboard service' -Result 'ctfmon restarted' -Status 'PASS' -Detail 'Verify Win+V'
            }
            if ($Name -match 'Snipping' -and $PSCmdlet.ShouldProcess('Snipping Tool', 'Re-register AppX + reset')) {
                Get-AppxPackage *ScreenSketch* -AllUsers | Reset-AppxPackage -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Snipping Tool' -Result 'AppX reset attempted' -Status 'PASS' -Detail 'ScreenSketch package'
            }
            if ($Name -match 'Search' -and $PSCmdlet.ShouldProcess('Windows Search', 'Restart WSearch')) {
                Restart-Service WSearch -Force -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'WSearch' -Result 'Restarted' -Status 'PASS' -Detail ''
            }
            if ($Name -match 'Sticky' -and $PSCmdlet.ShouldProcess('Sticky Keys', 'Disable stuck filter keys')) {
                Set-ItemProperty -Path 'HKCU:\Control Panel\Accessibility\StickyKeys' -Name Flags -Value '506' -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Sticky Keys' -Result 'Flags reset' -Status 'PASS' -Detail 'HKCU Accessibility'
            }
            if ($Name -match 'Night-Light' -and $PSCmdlet.ShouldProcess('Night Light', 'Toggle registry state')) {
                $nl = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount' -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Night Light' -Result 'Open Settings > System > Display > Night light' -Status 'WARN' -Detail 'Toggle off/on manually if still broken'
            }
            if ($Name -match 'Touchpad|Num-Lock' -and $PSCmdlet.ShouldProcess('Input devices', 'Restart tablet input service')) {
                Restart-Service TabletInputService -Force -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'TabletInputService' -Result 'Restarted' -Status 'PASS' -Detail ''
            }
            if ($Name -match 'Widgets|Taskbar|Action-Center|Focus' -and $PSCmdlet.ShouldProcess('ShellExperienceHost', 'Restart shell hosts')) {
                Get-Process ShellExperienceHost, StartMenuExperienceHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Shell hosts' -Result 'Restarted' -Status 'PASS' -Detail 'Widgets/Taskbar/Action Center'
            }
        }

        if ($Name -match 'WiFi|Ethernet|DNS|Internet|Connectivity|Limited|Hotspot|VPN|Proxy|PAC|Roaming|MTU') {
            Write-ProgressStep 3 $totalSteps $Activity 'Network stack'
            ipconfig /flushdns 2>&1 | Out-Null
            Add-ReportRow -Check 'DNS flush' -Result 'Done' -Status 'PASS' -Detail 'ipconfig /flushdns'
            if ($PSCmdlet.ShouldProcess('Network', 'Reset IP stack (netsh)')) {
                netsh winsock reset 2>&1 | Out-Null
                netsh int ip reset 2>&1 | Out-Null
                Add-ReportRow -Check 'Winsock/IP reset' -Result 'Done' -Status 'PASS' -Detail 'Reboot may be required'
            }
            $adapter = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | Select-Object -First 1
            if ($adapter) { Add-ReportRow -Check 'Active adapter' -Result $adapter.Name -Status 'INFO' -Detail $adapter.LinkSpeed }
            if ($Name -match 'MTU' -and $adapter -and $PSCmdlet.ShouldProcess($adapter.Name, 'Set MTU 1500')) {
                netsh interface ipv4 set subinterface "$($adapter.Name)" mtu=1500 store=persistent 2>&1 | Out-Null
                Add-ReportRow -Check 'MTU' -Result '1500' -Status 'PASS' -Detail $adapter.Name
            }
            if ($Name -match 'VPN' -or $Name -match 'Proxy|PAC') {
                $proxy = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Proxy enabled' -Result $proxy.ProxyEnable -Status 'INFO' -Detail $proxy.AutoConfigURL
            }
        }

        if ($Name -match 'Outlook|Teams|Office|Excel|Word|OneDrive|Click-To-Run|OST|PST|Cache') {
            Write-ProgressStep 3 $totalSteps $Activity 'Microsoft 365 clients'
            $teams = "$env:LOCALAPPDATA\Microsoft\Teams"
            $outlook = "$env:LOCALAPPDATA\Microsoft\Outlook"
            if ($Name -match 'Teams' -and $PSCmdlet.ShouldProcess('Teams', 'Clear cache + restart')) {
                Get-Process ms-teams, Teams -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                Remove-Item "$teams\Cache","$teams\GPUCache","$teams\blob_storage" -Recurse -Force -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Teams cache' -Result 'Cleared' -Status 'PASS' -Detail $teams
            }
            if ($Name -match 'Outlook|OST|PST' -and $PSCmdlet.ShouldProcess('Outlook', 'Safe mode guidance + OST check')) {
                $ost = Get-ChildItem $outlook -Filter *.ost -ErrorAction SilentlyContinue | Select-Object -First 3
                Add-ReportRow -Check 'OST files' -Result "$(@($ost).Count) found" -Status 'INFO' -Detail 'Use Outlook /safe; rebuild OST if corrupt'
                if ($Name -match 'Offline') { Add-ReportRow -Check 'Work Offline' -Result 'Uncheck Send/Receive > Work Offline' -Status 'WARN' -Detail 'Manual step' }
            }
            if ($Name -match 'Office|Click-To-Run' -and $PSCmdlet.ShouldProcess('Office', 'Quick repair trigger')) {
                $c2r = "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe"
                if (Test-Path $c2r) { Add-ReportRow -Check 'C2R' -Result 'Run setup /repair from Apps & Features' -Status 'WARN' -Detail $c2r }
            }
            if ($Name -match 'Excel|Word|Add-In') {
                Add-ReportRow -Check 'Office app' -Result 'Open safe mode; disable COM add-ins' -Status 'WARN' -Detail 'winword /safe excel /safe'
            }
        }

        if ($Name -match 'Printer|Print|Offline|Queue') {
            Write-ProgressStep 3 $totalSteps $Activity 'Print spooler'
            if ($PSCmdlet.ShouldProcess('Spooler', 'Restart + clear queue')) {
                Stop-Service Spooler -Force -ErrorAction SilentlyContinue
                Remove-Item "$env:SystemRoot\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
                Start-Service Spooler -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Spooler' -Result 'Restarted; queue cleared' -Status 'PASS' -Detail ''
            }
            Get-Printer -ErrorAction SilentlyContinue | ForEach-Object {
                Add-ReportRow -Check "Printer $($_.Name)" -Result $_.PrinterStatus -Status 'INFO' -Detail "Default=$($_.Default)"
            }
        }

        if ($Name -match 'Screen|Flicker|HDR|Display|Dock|Bluetooth|Audio|Mic|Camera|GPU|Monitor|Scaling') {
            Write-ProgressStep 3 $totalSteps $Activity 'Display / AV'
            Get-PnpDevice -Class Display,AudioEndpoint,Camera,Bluetooth -ErrorAction SilentlyContinue |
                ForEach-Object { Add-ReportRow -Check $_.FriendlyName -Result $_.Status -Status $(if ($_.Status -eq 'OK') {'PASS'} else {'WARN'}) -Detail $_.InstanceId }
            if ($Name -match 'Bluetooth' -and $PSCmdlet.ShouldProcess('Bluetooth', 'Restart service')) {
                Restart-Service bthserv -Force -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Bluetooth service' -Result 'Restarted' -Status 'PASS' -Detail ''
            }
            if ($Name -match 'HDR|Scaling|Flicker|Dock') {
                Add-ReportRow -Check 'Display guidance' -Result 'Update GPU driver; test cable/port; disable HDR trial' -Status 'WARN' -Detail ''
            }
        }

        if ($Name -match 'Edge|Chrome|Browser|Certificate|Sync') {
            Write-ProgressStep 3 $totalSteps $Activity 'Browser'
            if ($Name -match 'Edge' -and $PSCmdlet.ShouldProcess('Edge', 'Clear cache profile')) {
                Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" -Recurse -Force -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Edge cache' -Result 'Cleared' -Status 'PASS' -Detail ''
            }
            if ($Name -match 'Chrome') {
                Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Chrome' -Result 'Restart browser; check sync paused' -Status 'WARN' -Detail ''
            }
            if ($Name -match 'Certificate') {
                certutil -generateSSTFromWU $env:TEMP\roots.sst 2>&1 | Out-Null
                Add-ReportRow -Check 'Root update' -Result 'WU root SST generated' -Status 'INFO' -Detail "$env:TEMP\roots.sst"
            }
        }

        if ($Name -match 'Fast-Startup|Boot|Login|Startup|Slow|Memory|CPU|Temp|Disk|Battery|Superfetch|SysMain|Leak|High-') {
            Write-ProgressStep 3 $totalSteps $Activity 'Performance / boot'
            if ($Name -match 'Fast-Startup' -and $PSCmdlet.ShouldProcess('Power', 'Disable fast startup')) {
                powercfg /hibernate off 2>&1 | Out-Null
                Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Fast Startup' -Result 'Disabled' -Status 'PASS' -Detail 'Reboot recommended'
            }
            if ($Name -match 'Startup|Slow|Boot') {
                Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Select-Object -First 15 |
                    ForEach-Object { Add-ReportRow -Check 'Startup' -Result $_.Name -Status 'INFO' -Detail $_.Command }
            }
            if ($Name -match 'Memory|CPU|Leak|High-|Superfetch|SysMain') {
                Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 |
                    ForEach-Object { Add-ReportRow -Check $_.ProcessName -Result ("CPU {0:N1}s MEM {1:N0}MB" -f $_.CPU, ($_.WS/1MB)) -Status 'INFO' -Detail "PID $($_.Id)" }
                $sysmain = Get-Service SysMain -ErrorAction SilentlyContinue
                if ($sysmain) { Add-ReportRow -Check 'SysMain' -Result $sysmain.Status -Status 'INFO' -Detail $sysmain.StartType }
            }
            if ($Name -match 'Temp|Disk') {
                $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
                Add-ReportRow -Check 'C: free' -Result ("{0:N1} GB" -f ($disk.FreeSpace/1GB)) -Status $(if ($disk.FreeSpace -lt 5GB) {'WARN'} else {'PASS'}) -Detail ''
                if ($PSCmdlet.ShouldProcess('Temp', 'Clean user temp')) {
                    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Add-ReportRow -Check 'Temp clean' -Result 'Attempted' -Status 'PASS' -Detail $env:TEMP
                }
            }
        }

        if ($Name -match 'Quick-Access|Network-Drive|File-Association|Recycle|Explorer|Shell') {
            Write-ProgressStep 3 $totalSteps $Activity 'Explorer / shell'
            if ($Name -match 'Quick-Access|Network-Drive|Recycle' -and $PSCmdlet.ShouldProcess('Explorer', 'Restart explorer')) {
                Stop-Process explorer -Force -ErrorAction SilentlyContinue
                Start-Process explorer
                Add-ReportRow -Check 'Explorer' -Result 'Restarted' -Status 'PASS' -Detail ''
            }
            if ($Name -match 'File-Association' -and $PSCmdlet.ShouldProcess('File types', 'Restore default apps')) {
                Add-ReportRow -Check 'Defaults' -Result 'Settings > Apps > Default apps > Reset' -Status 'WARN' -Detail 'Manual or GPO'
            }
        }

        if ($Name -match 'USB|Thunderbolt|Selective|Dock|CalDigit|KVM|Barcode|Fingerprint|YubiKey|Drawing|Scanner|Signature|Foot-Pedal|Label-Printer') {
            Write-ProgressStep 3 $totalSteps $Activity 'USB / dock'
            if ($PSCmdlet.ShouldProcess('USB', 'Disable selective suspend')) {
                powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebb308ae3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>&1 | Out-Null
                powercfg /SETACTIVE SCHEME_CURRENT 2>&1 | Out-Null
                Add-ReportRow -Check 'USB selective suspend' -Result 'Disabled (AC)' -Status 'PASS' -Detail 'powercfg'
            }
            Get-PnpDevice -Class USB -ErrorAction SilentlyContinue | Where-Object Status -ne 'OK' |
                ForEach-Object { Add-ReportRow -Check $_.FriendlyName -Result $_.Status -Status 'WARN' -Detail 'Replug dock/device' }
            if ($Name -match 'Dock|CalDigit|ThinkPad|WD19|USB-C-Dock') {
                Get-PnpDevice -Class Net,USB,Display -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'Dock|Thunderbolt|USB4|DisplayLink' } |
                    ForEach-Object { Add-ReportRow -Check $_.FriendlyName -Result $_.Status -Status $(if ($_.Status -eq 'OK') {'PASS'} else {'WARN'}) -Detail $_.InstanceId }
                Add-ReportRow -Check 'Dock guidance' -Result 'Update dock firmware; test USB-C port/cable; reboot with dock connected' -Status 'WARN' -Detail 'Batch F Hardware'
            }
            if ($Name -match 'Barcode|Scanner|Signature|Foot-Pedal|Label-Printer|Drawing|YubiKey|Fingerprint' -and $PSCmdlet.ShouldProcess('HID devices', 'Rescan PnP')) {
                pnputil /scan-devices 2>&1 | Out-Null
                Get-PnpDevice -Class HIDClass,SmartCardReader -ErrorAction SilentlyContinue |
                    ForEach-Object { Add-ReportRow -Check $_.FriendlyName -Result $_.Status -Status 'INFO' -Detail $_.InstanceId }
            }
        }

        if ($Name -match 'Dell|HP|Lenovo|Surface|NVIDIA|AMD|Intel-ARC|Intel-iGPU|TPM|Battery|Thermal|NVMe|RAM|Firmware|Warranty|Service-Tag|eGPU|EDID|DisplayPort|HDMI|Monitor|Asset-Tag|PD-Charging|Fan-Always|Wear-Level|Vantage|Power-Manager|Image-Assistant|Command-Update|System-Update|Killer-WiFi|WiFi-6E|Multipoint|Conference|Headset|Travel-Dock|Alt-Mode|Lid-Close') {
            Write-ProgressStep 3 $totalSteps $Activity 'Hardware / vendor'
            $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
            $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
            if ($cs) { Add-ReportRow -Check 'Manufacturer' -Result $cs.Manufacturer -Status 'INFO' -Detail $cs.Model }
            if ($bios) { Add-ReportRow -Check 'Serial' -Result $bios.SerialNumber -Status 'INFO' -Detail $bios.SMBIOSBIOSVersion }

            if ($Name -match 'Dell') {
                $dcu = @('C:\Program Files\Dell\CommandUpdate\dcu-cli.exe','C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe') | Where-Object { Test-Path  } | Select-Object -First 1
                if ($dcu) { Add-ReportRow -Check 'Dell Command Update' -Result 'Installed' -Status 'PASS' -Detail $dcu } else { Add-ReportRow -Check 'Dell Command Update' -Result 'Not found' -Status 'WARN' -Detail 'Install from Dell support site' }
                if ($Name -match 'Service-Tag|Warranty') { Add-ReportRow -Check 'Dell warranty' -Result "Tag: $($bios.SerialNumber)" -Status 'INFO' -Detail 'https://www.dell.com/support/home/en-us' }
            }
            if ($Name -match 'HP') {
                $hpia = @('C:\HP\HPIA\HPIA.exe','C:\Program Files (x86)\HP\HP Image Assistant\HPIA.exe') | Where-Object { Test-Path  } | Select-Object -First 1
                if ($hpia) { Add-ReportRow -Check 'HP Image Assistant' -Result 'Installed' -Status 'PASS' -Detail $hpia } else { Add-ReportRow -Check 'HP Image Assistant' -Result 'Download HPIA' -Status 'WARN' -Detail 'HP support portal' }
            }
            if ($Name -match 'Lenovo') {
                $lsu = Get-ChildItem 'C:\Program Files (x86)\Lenovo\System Update' -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($lsu) { Add-ReportRow -Check 'Lenovo System Update' -Result $lsu.Name -Status 'PASS' -Detail $lsu.FullName } else { Add-ReportRow -Check 'Lenovo System Update' -Result 'Not found' -Status 'WARN' -Detail 'Install from Lenovo Vantage/support' }
            }
            if ($Name -match 'Surface') {
                Add-ReportRow -Check 'Surface' -Result 'Use Surface app or aka.ms/surface-support' -Status 'INFO' -Detail $cs.Model
            }

            if ($Name -match 'NVIDIA|AMD|Intel-ARC|Intel-iGPU|eGPU') {
                Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | ForEach-Object { Add-ReportRow -Check $_.FriendlyName -Result $_.Status -Status $(if ($_.Status -eq 'OK') {'PASS'} else {'WARN'}) -Detail $_.InstanceId }
                $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
                foreach ($g in $gpu) { Add-ReportRow -Check $g.Name -Result $g.DriverVersion -Status 'INFO' -Detail $g.AdapterRAM }
                if ($Name -match 'NVIDIA') { Add-ReportRow -Check 'NVIDIA' -Result 'Run nvidia-smi or GeForce Experience' -Status 'INFO' -Detail 'Update Studio/Game Ready driver' }
            }

            if ($Name -match 'TPM|Firmware|Secure-Boot|Asset-Tag') {
                try {
                    $tpm = Get-CimInstance -Namespace 'root\CIMV2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop
                    Add-ReportRow -Check 'TPM' -Result $tpm.SpecVersion -Status 'PASS' -Detail "Enabled=$($tpm.IsEnabled_InitialValue)"
                } catch { Add-ReportRow -Check 'TPM' -Result 'Unavailable' -Status 'WARN' -Detail $_.Exception.Message }
                $sb = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
                Add-ReportRow -Check 'Secure Boot' -Result $sb -Status 'INFO' -Detail ''
            }

            if ($Name -match 'Battery|Wear-Level|Thermal|Fan-Always|PD-Charging|Power-Manager|Vantage') {
                $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
                foreach ($b in $bat) {
                    Add-ReportRow -Check 'Battery' -Result ("$($b.EstimatedChargeRemaining)%") -Status 'INFO' -Detail $b.Name
                }
                if (-not $bat) { Add-ReportRow -Check 'Battery' -Result 'Desktop or no battery reported' -Status 'INFO' -Detail '' }
                powercfg /energy /duration 5 /output "$env:TEMP\energy-report.html" 2>&1 | Out-Null
                Add-ReportRow -Check 'Power report' -Result "$env:TEMP\energy-report.html" -Status 'INFO' -Detail 'Review thermal/throttle hints'
            }

            if ($Name -match 'NVMe|RAM|Storage-NVMe') {
                Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object { Add-ReportRow -Check $_.FriendlyName -Result $_.HealthStatus -Status $(if ($_.HealthStatus -eq 'Healthy') {'PASS'} else {'WARN'}) -Detail $_.MediaType }
                Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | ForEach-Object { Add-ReportRow -Check 'RAM slot' -Result ("$($_.Capacity/1GB) GB") -Status 'INFO' -Detail $_.DeviceLocator }
            }

            if ($Name -match 'DisplayPort|HDMI|EDID|Multi-Monitor|HDR|Alt-Mode|Dual-Monitor|Dual-Display|Conference|Headset|Multipoint|WiFi-6E|Killer') {
                Get-PnpDevice -Class Monitor,Display,AudioEndpoint -ErrorAction SilentlyContinue | Select-Object -First 12 |
                    ForEach-Object { Add-ReportRow -Check $_.FriendlyName -Result $_.Status -Status 'INFO' -Detail '' }
                if ($Name -match 'EDID|DisplayPort|HDMI|Multi-Monitor|HDR|Alt-Mode') {
                    Add-ReportRow -Check 'Display fix' -Result 'Test direct cable; disable HDR; update GPU driver; reset arrangement in Settings' -Status 'WARN' -Detail ''
                }
            }

            if ($Name -match 'Warranty|Service-Tag|Asset-Tag|Monitor-Serial|Dock-Serial') {
                Add-ReportRow -Check 'Inventory export' -Result 'Serial captured above' -Status 'INFO' -Detail 'Import to CMDB/asset tool'
            }
        }

        if ($Name -match 'RAID|MegaRAID|iSCSI|SAN|LUN|Storage-Spaces|ReFS|Cluster-Shared|VSS|Shadow-Copy|Hyper-V|OMSA|iDRAC|SSA|iLO|XClarity|ThinkSystem|IPMI|ServerView|Supermicro|Fujitsu|BMC|Quadro|Radeon-Pro|CUDA|OpenGL|DirectX|DisplayLink|Workstation|NUMA|MPIO|SMB-Multichannel|Jumbo-Frame|Veeam|Bare-Metal|Kernel-Dump|BugCheck|CAD-App|Plotter|SpacePilot|3D-Mouse|Chkdsk|Disk-Offline|Tiering|Spindle-SMART|Server-Firmware|Checkpoint-Disk|Rack-Asset|Server-Service|GPU-Bottleneck|GPU-Spec|Large-Excel|Plotter|Time-Machine-Server') {
            Write-ProgressStep 4 $totalSteps $Activity 'Server / RAID / workstation'
            Get-PhysicalDisk -ErrorAction SilentlyContinue | ForEach-Object {
                Add-ReportRow -Check $_.FriendlyName -Result $_.HealthStatus -Status $(if ($_.HealthStatus -eq 'Healthy') {'PASS'} else {'WARN'}) -Detail ("$($_.MediaType) $($_.OperationalStatus)")
            }
            Get-VirtualDisk -ErrorAction SilentlyContinue | ForEach-Object {
                Add-ReportRow -Check "Virtual disk $($_.FriendlyName)" -Result $_.HealthStatus -Status 'INFO' -Detail $_.Size
            }
            Get-Volume -ErrorAction SilentlyContinue | Where-Object DriveLetter | Select-Object -First 8 |
                ForEach-Object { Add-ReportRow -Check "Volume $($_.DriveLetter):" -Result $_.HealthStatus -Status 'INFO' -Detail ("{0:N1} GB free" -f ($_.SizeRemaining/1GB)) }

            if ($Name -match 'RAID|MegaRAID|Intel-RAID|Software-RAID|Spindle-SMART|Disk-Offline|Chkdsk') {
                Get-Disk -ErrorAction SilentlyContinue | ForEach-Object {
                    Add-ReportRow -Check "Disk $($_.Number)" -Result $_.OperationalStatus -Status 'INFO' -Detail ("$($_.PartitionStyle) $($_.Size/1GB) GB")
                }
                if ($Name -match 'Disk-Offline' -and $PSCmdlet.ShouldProcess('Offline disks', 'Bring online')) {
                    Get-Disk | Where-Object OperationalStatus -eq 'Offline' | ForEach-Object {
                        Set-Disk -Number $_.Number -IsOffline $false -ErrorAction SilentlyContinue
                        Add-ReportRow -Check "Disk $($_.Number) online" -Result 'Attempted' -Status 'PASS' -Detail $_.FriendlyName
                    }
                }
            }

            if ($Name -match 'iSCSI|SAN|LUN|MPIO|Jumbo-Frame') {
                Get-IscsiSession -ErrorAction SilentlyContinue | ForEach-Object {
                    Add-ReportRow -Check 'iSCSI session' -Result $_.TargetNodeAddress -Status 'INFO' -Detail $_.IsConnected
                }
                iscsicli SessionList 2>&1 | Out-String | ForEach-Object { Add-ReportRow -Check 'iscsicli' -Result 'Session list captured' -Status 'INFO' -Detail $_.Substring(0,[Math]::Min(200,$_.Length)) }
            }

            if ($Name -match 'Storage-Spaces|ReFS|Tiering|Cluster-Shared') {
                Get-StoragePool -ErrorAction SilentlyContinue | ForEach-Object {
                    Add-ReportRow -Check "Pool $($_.FriendlyName)" -Result $_.HealthStatus -Status 'INFO' -Detail $_.Size
                }
                if ($Name -match 'ReFS' -and $PSCmdlet.ShouldProcess('ReFS volumes', 'Integrity scan')) {
                    Get-Volume | Where-Object FileSystem -eq 'ReFS' | ForEach-Object {
                        Repair-Volume -DriveLetter $_.DriveLetter -Scan -ErrorAction SilentlyContinue | Out-Null
                        Add-ReportRow -Check "ReFS $($_.DriveLetter):" -Result 'Scan triggered' -Status 'PASS' -Detail ''
                    }
                }
            }

            if ($Name -match 'VSS|Shadow-Copy') {
                vssadmin list writers 2>&1 | Out-String | ForEach-Object { Add-ReportRow -Check 'VSS writers' -Result 'Listed' -Status 'INFO' -Detail 'Review failed writers' }
                vssadmin list shadows 2>&1 | Out-String | ForEach-Object { Add-ReportRow -Check 'Shadow copies' -Result 'Listed' -Status 'INFO' -Detail '' }
            }

            if ($Name -match 'Hyper-V|Checkpoint-Disk') {
                if (Get-Module -ListAvailable Hyper-V) {
                    Get-VM -ErrorAction SilentlyContinue | Select-Object -First 10 | ForEach-Object {
                        Add-ReportRow -Check "VM $($_.Name)" -Result $_.State -Status 'INFO' -Detail ("$($_.MemoryAssigned/1GB) GB RAM")
                    }
                    Get-VMSwitch -ErrorAction SilentlyContinue | ForEach-Object {
                        Add-ReportRow -Check "vSwitch $($_.Name)" -Result $_.SwitchType -Status 'INFO' -Detail ''
                    }
                } else { Add-ReportRow -Check 'Hyper-V' -Result 'Module not available' -Status 'WARN' -Detail 'Install Hyper-V role/tools' }
            }

            if ($Name -match 'OMSA|iDRAC') {
                $om = @('C:\Program Files\Dell\SysMgmt\omreport.exe','C:\Program Files\Dell\SysMgmt\omreport.exe') | Where-Object { Test-Path  } | Select-Object -First 1
                if ($om) { Add-ReportRow -Check 'Dell OMSA' -Result 'Installed' -Status 'PASS' -Detail $om } else { Add-ReportRow -Check 'Dell OMSA/iDRAC' -Result 'Install OMSA or use iDRAC web' -Status 'WARN' -Detail 'Batch G Server' }
            }
            if ($Name -match 'SSA|iLO') {
                Add-ReportRow -Check 'HP SSA/iLO' -Result 'Use HPE SSA or iLO Advanced' -Status 'INFO' -Detail 'Array configuration + remote health'
            }
            if ($Name -match 'XClarity|ThinkSystem') {
                Add-ReportRow -Check 'Lenovo XClarity' -Result 'Use XClarity Controller or LXCA' -Status 'INFO' -Detail 'RAID/firmware remote mgmt'
            }
            if ($Name -match 'IPMI|Supermicro|Fujitsu|BMC|ServerView') {
                Add-ReportRow -Check 'BMC/IPMI' -Result 'Ping BMC IP; verify web UI credentials' -Status 'WARN' -Detail 'Out-of-band management'
            }

            if ($Name -match 'Quadro|Radeon-Pro|CUDA|OpenGL|DirectX|Multi-GPU|Workstation|GPU-Bottleneck|CAD-App|DisplayLink|GPU-Spec|Large-Excel|3D-Mouse') {
                Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object {
                    Add-ReportRow -Check $_.Name -Result $_.DriverVersion -Status 'INFO' -Detail $_.VideoProcessor
                }
                if ($Name -match 'NVIDIA|Quadro|CUDA|SMI') {
                    $smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
                    if ($smi) { nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv 2>&1 | ForEach-Object { Add-ReportRow -Check 'nvidia-smi' -Result $_ -Status 'INFO' -Detail '' } }
                    else { Add-ReportRow -Check 'nvidia-smi' -Result 'Not in PATH' -Status 'WARN' -Detail 'Install NVIDIA driver toolkit' }
                }
                if ($Name -match 'OpenGL|DirectX') {
                    dxdiag /t "$env:TEMP\dxdiag-server-g.txt" 2>&1 | Out-Null
                    Add-ReportRow -Check 'DirectX diag' -Result "$env:TEMP\dxdiag-server-g.txt" -Status 'INFO' -Detail 'Review display/GPU tabs'
                }
            }

            if ($Name -match 'Veeam|Bare-Metal|Windows-Server-Backup|Kernel-Dump|BugCheck|NUMA|Disk-Queue|Server-Service|Rack-Asset|RAID-Array-Serial') {
                $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
                if ($cs) { Add-ReportRow -Check 'Server role' -Result $cs.SystemType -Status 'INFO' -Detail ("Domain=$($cs.PartOfDomain) NUMA=$($cs.NumberOfLogicalProcessors) cores") }
                if ($Name -match 'NUMA') {
                    Get-CimInstance Win32_NumaNode -ErrorAction SilentlyContinue | ForEach-Object { Add-ReportRow -Check "NUMA node $($_.NodeIndex)" -Result $_.OperatingSystemCaption -Status 'INFO' -Detail '' }
                }
                if ($Name -match 'BugCheck|Kernel-Dump') {
                    Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WER-SystemErrorReporting'; StartTime=(Get-Date).AddDays(-30)} -MaxEvents 5 -ErrorAction SilentlyContinue |
                        ForEach-Object { Add-ReportRow -Check 'BugCheck event' -Result $_.TimeCreated -Status 'WARN' -Detail $_.Message.Substring(0,[Math]::Min(120,$_.Message.Length)) }
                }
            }

            if ($Name -match 'Plotter|SpacePilot|3D-Mouse') {
                Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Plotter|DesignJet|Large' } |
                    ForEach-Object { Add-ReportRow -Check $_.Name -Result $_.PrinterStatus -Status 'INFO' -Detail 'Workstation peripheral' }
            }
        }

        Write-ProgressStep 5 $totalSteps $Activity 'Common problem module complete'
        Add-ReportRow -Check 'Script' -Result $Name -Status 'INFO' -Detail '29_Hardware-Driver-Management'

        if ($Name -match 'Enterprise|Deep-Audit|Auto-Repair|Stack-Reset|Health-Triage|Anomaly-Detect|Evidence-Report|Policy-Validate') {
            Write-ProgressStep 6 $totalSteps $Activity 'Enterprise module depth'
            $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Running' -and $_.StartType -eq 'Automatic' } | Select-Object -First 5
            foreach ($s in $svc) { Add-ReportRow -Check "Service $($s.Name)" -Result $s.Status -Status 'WARN' -Detail $s.DisplayName }
            $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
            if ($disk) { Add-ReportRow -Check 'Disk C' -Result ("{0:N1} GB free" -f ($disk.FreeSpace/1GB)) -Status 'INFO' -Detail '' }
            Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 3 |
                ForEach-Object { Add-ReportRow -Check 'Recent update' -Result $_.HotFixID -Status 'INFO' -Detail $_.Description }
        }

        if ($Name -match 'Quick-Audit|Quick-Repair|Reset-Stack|User-Triage|Issue-Detect|One-Click-Fix|Helpdesk-Report|Policy-Check') {
            Write-ProgressStep 6 $totalSteps $Activity 'Helpdesk module depth'
            Add-ReportRow -Check 'Helpdesk user' -Result $env:USERNAME -Status 'INFO' -Detail $env:USERPROFILE
            $uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
            Add-ReportRow -Check 'Last boot' -Result $uptime -Status 'INFO' -Detail 'Batch E IT Support'
            $recent = Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=(Get-Date).AddDays(-3)} -MaxEvents 5 -ErrorAction SilentlyContinue
            foreach ($ev in $recent) { Add-ReportRow -Check 'Recent app error' -Result $ev.ProviderName -Status 'WARN' -Detail $ev.Message.Substring(0,[Math]::Min(120,$ev.Message.Length)) }
        }
    Write-ProgressStep $totalSteps $totalSteps $Activity 'Export report'
    Export-HtmlReport -Title 'Server Firmware Baseline Audit' -JoinState $Join.Label -ComputerName $env:COMPUTERNAME -LogPath $LogPath -ScriptFileName $ScriptName -ReportPath $ReportPath | Out-Null
    Write-CompletionSummary -LogPath $LogPath -ReportPath $ReportPath
    if ($OpenReport) { Open-HtmlReportIfInteractive -ReportPath $ReportPath }
    $exitCode = Get-ScriptExitCode
} catch {
    Write-Status "FATAL: $($_.Exception.Message)" -Level ERROR
    try { Add-ReportRow -Check 'Fatal' -Result 'Exception' -Status 'FAIL' -Detail $_.Exception.Message; Export-HtmlReport -Title 'Server Firmware Baseline Audit' -JoinState 'Unknown' -ComputerName $env:COMPUTERNAME -LogPath $LogPath -ScriptFileName $ScriptName -ReportPath $ReportPath | Out-Null } catch {}
    $exitCode = 2
} finally { Write-Progress -Activity $Activity -Completed; Stop-Transcript | Out-Null }
exit $exitCode