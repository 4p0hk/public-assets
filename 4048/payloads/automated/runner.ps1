#requires -Version 5.1
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'wrapper-config.json')
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:debug = $true

function Write-Section($text) { if ($script:debug) { Write-Host ''; Write-Host ('==== ' + $text + ' ====') -ForegroundColor Cyan } }
function Write-Info($text)    { if ($script:debug) { Write-Host ('[INFO] ' + $text) -ForegroundColor Cyan } }
function Write-Ok($text)      { if ($script:debug) { Write-Host ('[ OK ] ' + $text) -ForegroundColor Green } }
function Write-Warn2($text)   { if ($script:debug) { Write-Host ('[WARN] ' + $text) -ForegroundColor Yellow } }
function Write-Err($text)     { if ($script:debug) { Write-Host ('[FAIL] ' + $text) -ForegroundColor Red } }
function Write-Opsec($text)   { if (-not $script:debug) { Write-Host $text } }

function Die($msg, $code) {
    Write-Err $msg
    Write-Opsec 'exiting'
    if (-not $code) { $code = 1 }
    exit $code
}

function Get-EstStamp {
    $utc = (Get-Date).ToUniversalTime()
    try {
        $tz  = [System.TimeZoneInfo]::FindSystemTimeZoneById('Eastern Standard Time')
        $est = [System.TimeZoneInfo]::ConvertTimeFromUtc($utc, $tz)
    } catch {
        $est = (Get-Date)
    }
    return ($est.ToString('MM/dd/yyyy hh:mm tt') + ' EST')
}

function Mask-Token($t) {
    if (-not $t) { return '<empty>' }
    if ($t.Length -le 8) { return ('*' * $t.Length) }
    return ($t.Substring(0,4) + ('*' * ($t.Length - 8)) + $t.Substring($t.Length - 4, 4))
}

function Format-Duration([int]$Seconds) {
    if ($Seconds -le 0) { return '0s' }
    $ts = [TimeSpan]::FromSeconds($Seconds)
    if ($ts.TotalHours -ge 1) {
        return ('{0}h {1:D2}m {2:D2}s' -f [int][Math]::Floor($ts.TotalHours), $ts.Minutes, $ts.Seconds)
    }
    if ($ts.TotalMinutes -ge 1) {
        return ('{0}m {1:D2}s' -f [int][Math]::Floor($ts.TotalMinutes), $ts.Seconds)
    }
    return ($ts.Seconds.ToString() + 's')
}

function Wait-WithTimer([int]$Seconds, [string]$Reason) {
    if ($Seconds -le 0) {
        if ($script:debug -and $Reason) { Write-Info ('no wait (' + $Reason + ')') }
        return
    }
    if ($script:debug) {
        Write-Info ('sleeping ' + (Format-Duration $Seconds) + ' (' + $Reason + ')')
    }
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        $r = $end - (Get-Date)
        if ($r.TotalSeconds -lt 0) { break }
        if ($script:debug) {
            $disp = '{0:D2}:{1:D2}:{2:D2}' -f [int][Math]::Floor($r.TotalHours), $r.Minutes, $r.Seconds
            Write-Host -NoNewline ("`r[wait] $disp until next stage  ")
        } else {
            $disp = Format-Duration ([int]$r.TotalSeconds)
            Write-Host -NoNewline ("`raction $script:currentAction/$script:totalActions" + ': waiting ' + $disp + '   ')
        }
        Start-Sleep -Seconds 1
    }
    Write-Host ''
}

function Get-NextCronTick([DateTime]$AfterTime, [int[]]$CronMinutes, [switch]$Inclusive) {
    $start = if ($Inclusive) { $AfterTime } else { $AfterTime.AddSeconds(1) }
    $minuteBoundary = (Get-Date -Year $start.Year -Month $start.Month -Day $start.Day -Hour $start.Hour -Minute $start.Minute -Second 0 -Millisecond 0)
    if ($minuteBoundary -lt $start) { $minuteBoundary = $minuteBoundary.AddMinutes(1) }
    for ($i = 0; $i -lt 1440; $i++) {
        $candidate = $minuteBoundary.AddMinutes($i)
        if ($CronMinutes -contains $candidate.Minute) {
            return $candidate
        }
    }
    throw 'No cron tick found in next 24h - check cron_minutes configuration'
}

function Resolve-StageWait($stage, $timing) {
    $strategy = if ($stage.PSObject.Properties.Name -contains 'wait_strategy') { [string]$stage.wait_strategy } else { 'fixed_seconds' }
    switch ($strategy) {
        'none' {
            return @{ Seconds = 0; Reason = 'no wait directive (last stage or operator-skipped)' }
        }
        'fixed_seconds' {
            $delay = if ($stage.PSObject.Properties.Name -contains 'delay_seconds') { [int]$stage.delay_seconds } else { 10 }
            return @{ Seconds = $delay; Reason = 'fixed delay between stages' }
        }
        'next_clean_cron' {
            if (-not $timing) {
                Die 'wait_strategy=next_clean_cron requires a top-level timing block in wrapper-config.json' 2
            }
            foreach ($k in @('lookback_seconds','cron_minutes','throttle_seconds')) {
                if (-not ($timing.PSObject.Properties.Name -contains $k)) {
                    Die ('timing block missing required key: ' + $k + ' (required by wait_strategy=next_clean_cron)') 2
                }
            }
            $now = Get-Date
            $lookbackSec = [int]$timing.lookback_seconds
            $throttleSec = [int]$timing.throttle_seconds
            $ingestBuf = if ($timing.PSObject.Properties.Name -contains 'ingest_buffer_seconds') { [int]$timing.ingest_buffer_seconds } else { 60 }
            if ($ingestBuf -ge $lookbackSec) {
                Die ('ingest_buffer_seconds (' + $ingestBuf + ') must be < lookback_seconds (' + $lookbackSec + ') so T2 lands inside C_target lookback') 2
            }
            $cronMinutes = @()
            foreach ($m in $timing.cron_minutes) { $cronMinutes += [int]$m }
            $cronMinutes = $cronMinutes | Sort-Object
            $cConsume     = Get-NextCronTick -AfterTime $now -CronMinutes $cronMinutes -Inclusive
            $throttleClear = $cConsume.AddSeconds($throttleSec)
            $lookbackClear = $now.AddSeconds($lookbackSec)
            if ($throttleClear -ge $lookbackClear) { $maxClear = $throttleClear; $bound = 'throttle-bound' }
            else                                   { $maxClear = $lookbackClear; $bound = 'lookback-bound' }
            $cTarget  = Get-NextCronTick -AfterTime $maxClear -CronMinutes $cronMinutes
            $fireTime = $cTarget.AddSeconds(-$ingestBuf)
            $waitSec  = [int]($fireTime - $now).TotalSeconds
            if ($waitSec -lt 0) { $waitSec = 0 }
            $other = if ($bound -eq 'throttle-bound') { 'lookback clears ' + $lookbackClear.ToString('HH:mm:ss') }
                     else                            { 'throttle clears ' + $throttleClear.ToString('HH:mm:ss') }
            $reason = ('cron-aware: target ' + $cTarget.ToString('HH:mm:ss') + ', firing at ' + $fireTime.ToString('HH:mm:ss') + ' (' + $bound + '; ' + $other + ')')
            return @{ Seconds = $waitSec; Reason = $reason }
        }
        default {
            Die ('unknown wait_strategy: ' + $strategy + ' (expected: fixed_seconds | next_clean_cron | none)') 2
        }
    }
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Err ('config not found: ' + $ConfigPath)
    Write-Host ''
    Write-Host 'Place wrapper-config.json next to this script.' -ForegroundColor Yellow
    Write-Host 'See wrapper-config.example.json for the expected shape.' -ForegroundColor Yellow
    exit 2
}

try {
    $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
} catch {
    Die ('config json parse failed: ' + $_.Exception.Message) 2
}

$script:debug = if ($cfg.PSObject.Properties.Name -contains 'debug') { [bool]$cfg.debug } else { $true }
$script:totalActions = $cfg.stages.Count + 2
$script:currentAction = 0

Write-Section 'Config + Auth'

$EXPECTED_SCHEMA = 3
$actualSchema = if ($cfg.PSObject.Properties.Name -contains 'schema_version') { [int]$cfg.schema_version } else { 0 }
if ($actualSchema -ne $EXPECTED_SCHEMA) {
    Write-Err ('wrapper-config schema_version mismatch (expected ' + $EXPECTED_SCHEMA + ', got ' + $actualSchema + ')')
    Write-Host ''
    Write-Host 'Your wrapper-config.json is from an older repo state. Refresh:' -ForegroundColor Yellow
    Write-Host '  cd payloads\automated' -ForegroundColor Yellow
    Write-Host '  del wrapper-config.json' -ForegroundColor Yellow
    Write-Host '  copy wrapper-config.example.json wrapper-config.json' -ForegroundColor Yellow
    Write-Host '  notepad wrapper-config.json   # paste PAT, set issue_key' -ForegroundColor Yellow
    exit 2
}

$required = @('rule_name','jira','stages','validator','cleanup')
foreach ($k in $required) {
    if (-not ($cfg.PSObject.Properties.Name -contains $k)) {
        Die ('config missing required key: ' + $k) 2
    }
}
foreach ($k in @('base_url','issue_key','pat','dry_run')) {
    if (-not ($cfg.jira.PSObject.Properties.Name -contains $k)) {
        Die ('config.jira missing required key: ' + $k) 2
    }
}

$pat = [string]$cfg.jira.pat
if (-not $pat -or $pat.Trim().Length -eq 0) {
    Write-Err 'config.jira.pat is empty.'
    Write-Host ''
    Write-Host 'Place your JIRA PAT into wrapper-config.json under jira.pat.' -ForegroundColor Yellow
    Write-Host ('  config: ' + $ConfigPath) -ForegroundColor Yellow
    exit 2
}

$ruleName = [string]$cfg.rule_name
$baseUrl  = ([string]$cfg.jira.base_url).TrimEnd('/')
$issueKey = [string]$cfg.jira.issue_key
$dryRun   = [bool]$cfg.jira.dry_run

$payloadRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $payloadRoot)) {
    Die ('payload root not found: ' + $payloadRoot) 2
}

$validatorScript = Join-Path $payloadRoot ([string]$cfg.validator)
$cleanupScript   = Join-Path $payloadRoot ([string]$cfg.cleanup)

$missingPaths = @()
foreach ($stage in $cfg.stages) {
    $sp = Join-Path $payloadRoot ([string]$stage.script)
    if (-not (Test-Path -LiteralPath $sp)) { $missingPaths += $sp }
}
if (-not (Test-Path -LiteralPath $validatorScript)) { $missingPaths += $validatorScript }
if (-not (Test-Path -LiteralPath $cleanupScript))   { $missingPaths += $cleanupScript }

if ($missingPaths.Count -gt 0) {
    Write-Err 'wrapper-config references paths that do not exist:'
    foreach ($p in $missingPaths) { Write-Host ('  - ' + $p) -ForegroundColor Red }
    Write-Host ''
    Write-Host 'Likely a stale wrapper-config.json from before a layout/rename change.' -ForegroundColor Yellow
    Write-Host 'Refresh:' -ForegroundColor Yellow
    Write-Host '  cd payloads\automated' -ForegroundColor Yellow
    Write-Host '  del wrapper-config.json' -ForegroundColor Yellow
    Write-Host '  copy wrapper-config.example.json wrapper-config.json' -ForegroundColor Yellow
    Write-Host '  notepad wrapper-config.json   # paste PAT, set issue_key' -ForegroundColor Yellow
    exit 5
}

Write-Info ('rule:        ' + $ruleName)
Write-Info ('jira url:    ' + $baseUrl)
Write-Info ('issue key:   ' + $issueKey)
Write-Info ('jira mode:   ' + $(if ($dryRun) { 'DRY-RUN (no posts)' } else { 'LIVE' }))
Write-Info ('pat:         ' + (Mask-Token $pat))
Write-Info ('payload dir: ' + $payloadRoot)
Write-Info ('stages:      ' + $cfg.stages.Count)

if (-not $dryRun) {
    Write-Section 'JIRA Auth Probe'
    try {
        $headers = @{
            'Accept'        = 'application/json'
            'Authorization' = 'Bearer ' + $pat
            'User-Agent'    = 'wf4048-wrapper-ps5'
        }
        $resp = Invoke-WebRequest -Uri ($baseUrl + '/rest/api/2/myself') `
            -Method GET -Headers $headers -UseBasicParsing -TimeoutSec 30
        $me = $resp.Content | ConvertFrom-Json
        Write-Ok ('authenticated as: ' + $me.name + ' (' + $me.displayName + ')')
    } catch {
        Die ('jira auth probe failed: ' + $_.Exception.Message) 3
    }
}

Write-Opsec 'job started'

function Build-Comment([string]$artifactPath) {
    $stamp = Get-EstStamp
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('Rule: ' + $ruleName + ' ')
    [void]$sb.AppendLine('Execution Time: ' + $stamp + ' ')
    [void]$sb.AppendLine('User: ' + $env:USERNAME)
    [void]$sb.AppendLine('Hostname: ' + $env:COMPUTERNAME)
    [void]$sb.Append('Artifact Path: ' + $artifactPath)
    return $sb.ToString()
}

function Post-Comment([string]$body) {
    if ($script:debug) {
        Write-Host ''
        Write-Host '------ jira comment payload ------' -ForegroundColor DarkGray
        Write-Host $body -ForegroundColor White
        Write-Host '----------------------------------' -ForegroundColor DarkGray
    }
    if ($dryRun) {
        if ($script:debug) { Write-Warn2 'DRY-RUN: skipping POST to JIRA.' }
        return
    }
    $headers = @{
        'Accept'        = 'application/json'
        'Authorization' = 'Bearer ' + $pat
        'Content-Type'  = 'application/json'
        'User-Agent'    = 'wf4048-wrapper-ps5'
    }
    $payload = @{ body = $body } | ConvertTo-Json -Compress
    $url = $baseUrl + '/rest/api/2/issue/' + $issueKey + '/comment'
    try {
        $resp = Invoke-WebRequest -Uri $url -Method POST -Headers $headers `
            -Body $payload -UseBasicParsing -TimeoutSec 60
        $j = $resp.Content | ConvertFrom-Json
        Write-Ok ('jira comment posted. id=' + $j.id)
    } catch {
        Write-Err ('jira comment POST failed: ' + $_.Exception.Message)
        if ($_.Exception.Response) {
            try {
                $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errBody = $sr.ReadToEnd()
                Write-Host $errBody -ForegroundColor Red
            } catch { }
        }
    }
}

function Run-Stage([string]$label, [string]$scriptPath) {
    if ($script:debug) {
        Write-Section $label
        Write-Info ('artifact: ' + $scriptPath)
        Write-Host ''
    }
    $ext = [System.IO.Path]::GetExtension($scriptPath).ToLowerInvariant()
    switch ($ext) {
        '.bat' { $launcher = 'cmd.exe';        $passArgs = @('/c', $scriptPath) }
        '.cmd' { $launcher = 'cmd.exe';        $passArgs = @('/c', $scriptPath) }
        '.ps1' { $launcher = 'powershell.exe'; $passArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath) }
        default { Die ('unsupported script extension: ' + $ext) 5 }
    }
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($script:debug) {
            & $launcher @passArgs 2>&1 | ForEach-Object { Write-Host $_ }
        } else {
            & $launcher @passArgs *>&1 | Out-Null
        }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEAP
    }
    if ($script:debug) {
        Write-Host ''
        if ($code -ne 0) {
            Write-Err ($label + ' exited with code ' + $code)
        } else {
            Write-Ok ($label + ' completed.')
        }
    }
    return $code
}

$pipelineFailCode = 0
$stageNum = 0
foreach ($stage in $cfg.stages) {
    $stageNum++
    $script:currentAction = $stageNum
    $stageName   = [string]$stage.name
    $stageScript = Join-Path $payloadRoot ([string]$stage.script)
    Write-Opsec ("action $script:currentAction/$script:totalActions" + ': started')
    $rc = Run-Stage ('Stage ' + $stageNum + ' - ' + $stageName) $stageScript
    if ($rc -ne 0) {
        Write-Err ('stage ' + $stageNum + ' (' + $stageName + ') failed with code ' + $rc)
        Write-Opsec ("action $script:currentAction/$script:totalActions" + ': failed')
        $pipelineFailCode = 6
        break
    }
    Write-Opsec ("action $script:currentAction/$script:totalActions" + ': done')
    Post-Comment (Build-Comment $stageScript)
    $timingBlock = if ($cfg.PSObject.Properties.Name -contains 'timing') { $cfg.timing } else { $null }
    $waitInfo = Resolve-StageWait $stage $timingBlock
    Wait-WithTimer -Seconds $waitInfo.Seconds -Reason $waitInfo.Reason
}

$validatorRc = -1
if ($pipelineFailCode -eq 0) {
    $script:currentAction = $cfg.stages.Count + 1
    Write-Opsec ("action $script:currentAction/$script:totalActions" + ': started')
    $validatorRc = Run-Stage 'Validator' $validatorScript
    if ($validatorRc -eq 0) {
        Write-Opsec ("action $script:currentAction/$script:totalActions" + ': done')
    } else {
        Write-Opsec ("action $script:currentAction/$script:totalActions" + ': failed')
    }
}

$script:currentAction = $cfg.stages.Count + 2
Write-Opsec ("action $script:currentAction/$script:totalActions" + ': started')
$cleanupRc = Run-Stage 'Cleanup' $cleanupScript
if ($cleanupRc -ne 0) {
    Write-Warn2 ('cleanup exited ' + $cleanupRc + ' -- leftover artifacts may remain under %USERPROFILE%\bops4048\exfil')
    Write-Opsec ("action $script:currentAction/$script:totalActions" + ': done (with warnings)')
} else {
    Write-Opsec ("action $script:currentAction/$script:totalActions" + ': done')
}

Write-Section 'RESULT'
if ($pipelineFailCode -ne 0) {
    Write-Err ('pipeline aborted at stage ' + $stageNum + ' (validator skipped). cleanup ran.')
    Write-Opsec 'exiting'
    exit $pipelineFailCode
}
if ($validatorRc -eq 0) {
    Write-Ok 'all stages completed. validator [PASS]. cleanup ran.'
    Write-Opsec 'exiting'
    exit 0
}
Write-Err ('validator [FAIL] (exit ' + $validatorRc + '). cleanup ran.')
Write-Opsec 'exiting'
exit $validatorRc
