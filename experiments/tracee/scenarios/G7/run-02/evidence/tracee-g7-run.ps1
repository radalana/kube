param(
    [ValidateSet("run-01","run-02","run-03")]
    [string]$Run,
    [string]$ScenarioScript
)

$ErrorActionPreference = "Stop"

$namespace = "database"
$targetPod = "mariadb-galera-0"
$targetContainer = "mariadb"
$traceeNamespace = "tracee"
$nodes = @("master","worker1","worker2")
$jobs = @("g1-crud","g2-schema-migration","g3-backup")

# Expected location:
# experiments\tracee\scenarios\G7\tracee-g7-run.ps1
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\.."))
$g7Root = Join-Path $repoRoot "experiments\tracee\scenarios\G7"
New-Item -ItemType Directory -Force -Path $g7Root | Out-Null

if (-not $Run) {
    foreach ($r in @("run-01","run-02","run-03")) {
        if (-not (Test-Path (Join-Path $g7Root $r))) {
            $Run = $r
            break
        }
    }
}
if (-not $Run) { throw "run-01, run-02 and run-03 already exist." }

$g7 = Join-Path $g7Root $Run
if (Test-Path $g7) { throw "Evidence directory already exists: $g7" }
New-Item -ItemType Directory -Force -Path $g7 | Out-Null


function Find-G7Script {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        return (Resolve-Path $ExplicitPath -ErrorAction Stop).Path
    }

    $root = Join-Path $repoRoot "tests\scenarios"
    if (-not (Test-Path $root)) {
        throw "tests\scenarios was not found. Pass -ScenarioScript explicitly."
    }

    $matches = @(
        Get-ChildItem $root -Recurse -File -Filter *.ps1 |
        Where-Object {
            try {
                $t = Get-Content $_.FullName -Raw
                $t -match 'Starting G7:\s*combined benign workload' -and
                $t -match 'G7 combined benign workload completed successfully'
            } catch { $false }
        }
    )

    if ($matches.Count -eq 0) {
        throw "Validated G7 script was not found automatically. Pass -ScenarioScript explicitly."
    }

    if ($matches.Count -gt 1) {
        $names = ($matches.FullName -join "`n")
        throw "More than one G7 script matched. Pass -ScenarioScript explicitly.`n$names"
    }

    return $matches[0].FullName
}


function Get-ClusterUtc {
    $raw = @(ssh master "date -u +%s%N")
    if ($LASTEXITCODE -ne 0) { throw "Could not read master UTC time." }

    $nsText = ($raw -join "").Trim()
    if ($nsText -notmatch '^\d+$') { throw "Unexpected master time: $nsText" }

    $ms = [Int64][decimal]::Floor(([decimal]$nsText) / 1000000)
    ([DateTimeOffset]::FromUnixTimeMilliseconds($ms)).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}


function Iso-ToNs {
    param([string]$Timestamp)

    $dto = [DateTimeOffset]::Parse(
        $Timestamp,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal
    ).ToUniversalTime()

    [Int64](($dto.UtcDateTime.Ticks - [DateTimeOffset]::UnixEpoch.UtcDateTime.Ticks) * 100)
}


function Get-TargetPod {
    param([switch]$AllowMissing)

    $raw = @(k get pod $targetPod -n $namespace -o json 2>$null)
    if ($LASTEXITCODE -ne 0 -or $raw.Count -eq 0) {
        if ($AllowMissing) { return $null }
        throw "Could not read $targetPod."
    }

    $p = ($raw -join "`n") | ConvertFrom-Json
    $ready = $p.status.conditions | Where-Object type -eq "Ready" | Select-Object -First 1
    $cs = $p.status.containerStatuses | Where-Object name -eq $targetContainer | Select-Object -First 1

    [PSCustomObject]@{
        Pod         = $p.metadata.name
        UID         = $p.metadata.uid
        Node        = $p.spec.nodeName
        Phase       = $p.status.phase
        Ready       = ($ready.status -eq "True")
        ContainerID = if ($cs) { $cs.containerID } else { $null }
        Restarts    = if ($cs) { [int]$cs.restartCount } else { $null }
        PodIP       = $p.status.podIP
    }
}


function Get-TraceeAgents {
    $items = (k get pods -n $traceeNamespace -o json | ConvertFrom-Json).items

    foreach ($p in $items) {
        if (
            $p.metadata.name -like "tracee-*" -and
            $p.metadata.name -notlike "tracee-operator*" -and
            $nodes -contains $p.spec.nodeName
        ) {
            $restarts = 0
            if ($p.status.containerStatuses) {
                $sum = ($p.status.containerStatuses | Measure-Object restartCount -Sum).Sum
                if ($null -ne $sum) { $restarts = [int]$sum }
            }

            [PSCustomObject]@{
                Node     = $p.spec.nodeName
                Pod      = $p.metadata.name
                Phase    = $p.status.phase
                Restarts = $restarts
            }
        }
    }
}


function Redact-SensitiveEnvEntry {
    param([string]$Entry)

    if ($null -eq $Entry) {
        return $Entry
    }

    $separator = $Entry.IndexOf("=")

    if ($separator -lt 1) {
        return $Entry
    }

    $key = $Entry.Substring(0, $separator)

    if (
        $key -match '(?i)(PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|PRIVATE_KEY)' -or
        $key -eq 'WSREP_SST_OPT_REMOTE_AUTH'
    ) {
        return "$key=<redacted>"
    }

    return $Entry
}


function Redact-TraceeLine {
    param([string]$Line)

    # Parse first and redact only structured environment entries.
    # This avoids modifying quoted command strings such as
    # --password="$MIGRATION_PASSWORD", which previously corrupted JSON.
    try {
        $event = $Line | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        # Preserve non-JSON diagnostic lines unchanged.
        return $Line
    }

    if ($event.args) {
        foreach ($arg in @($event.args)) {
            if ($arg.name -eq "env" -and $null -ne $arg.value) {
                $redactedEnv = @(
                    foreach ($entry in @($arg.value)) {
                        Redact-SensitiveEnvEntry ([string]$entry)
                    }
                )

                $arg.value = $redactedEnv
            }
        }
    }

    return ($event | ConvertTo-Json -Depth 100 -Compress)
}


function Redact-ScenarioLine {
    param([string]$Line)

    $x = [regex]::Replace(
        $Line,
        '(?i)(wsrep_sst_auth\s*=\s*).*$',
        '${1}<redacted>'
    )

    [regex]::Replace(
        $x,
        '(?i)\b((?:PASSWORD|PASSWD|SECRET|TOKEN)\s*=\s*)\S+',
        '${1}<redacted>'
    )
}


function Collect-Tracee {
    param(
        [string]$SinceTime,
        [array]$Agents
    )

    foreach ($node in $nodes) {
        $agent = $Agents | Where-Object Node -eq $node | Select-Object -First 1
        if (-not $agent) { throw "No Tracee agent found on $node." }

        $outFile = Join-Path $g7 "$node-since-start.jsonl"
        $errFile = Join-Path $g7 "$node-tracee-log-errors.txt"

        $lines = @(
            k logs -n $traceeNamespace $agent.Pod --since-time=$SinceTime 2> $errFile
        )
        if ($LASTEXITCODE -ne 0) { throw "Tracee log collection failed on $node." }

        New-Item -ItemType File -Force -Path $outFile | Out-Null
        if ($lines.Count -gt 0) {
            $sanitizedLines = @(
                foreach ($line in $lines) {
                    $sanitized = Redact-TraceeLine ([string]$line)

                    # Tracee event/error output should be JSON per line.
                    # Fail immediately if sanitization ever makes a valid JSON
                    # line invalid, instead of silently losing it later.
                    try {
                        $null = $sanitized | ConvertFrom-Json -ErrorAction Stop
                    }
                    catch {
                        throw "Invalid JSON after Tracee redaction on ${node}: $sanitized"
                    }

                    $sanitized
                }
            )

            $sanitizedLines |
                Set-Content $outFile -Encoding utf8
        }
    }
}


function Filter-Window {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [Int64]$StartNs,
        [Int64]$EndNs
    )

    New-Item -ItemType File -Force -Path $OutputFile | Out-Null

    $selected = @(
        foreach ($line in Get-Content $InputFile -ErrorAction SilentlyContinue) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            try { $e = $line | ConvertFrom-Json -ErrorAction Stop }
            catch { continue }

            if ($null -eq $e.timestamp) { continue }

            $ts = [Int64]$e.timestamp
            if ($ts -ge $StartNs -and $ts -le $EndNs) { $line }
        }
    )

    if ($selected.Count -gt 0) {
        $selected | Set-Content $OutputFile -Encoding utf8
    }
}


function Build-DetectionSummary {
    $detections = @()

    foreach ($node in $nodes) {
        $file = Join-Path $g7 "$node-window.jsonl"

        foreach ($line in Get-Content $file -ErrorAction SilentlyContinue) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            try { $e = $line | ConvertFrom-Json -ErrorAction Stop }
            catch { continue }

            $policies = @($e.matchedPolicies | Where-Object { $_ -like "falco-ref-*" })
            if ($policies.Count -eq 0) { continue }

            $detections += [PSCustomObject]@{
                Node      = $node
                Timestamp = $e.timestamp
                Event     = $e.eventName
                Process   = $e.processName
                PID       = $e.processId
                Container = $e.containerId
                Policies  = ($policies -join ", ")
            }
        }
    }

    if ($detections.Count -gt 0) {
        $detections |
            Format-Table -AutoSize |
            Out-String -Width 350 |
            Set-Content (Join-Path $g7 "detections-overview.txt")

        $detections |
            Group-Object Policies |
            Sort-Object Count -Descending |
            Select-Object Count, Name |
            Format-Table -AutoSize |
            Out-String |
            Set-Content (Join-Path $g7 "detections-summary.txt")

        $detections |
            Group-Object Node |
            Sort-Object Name |
            Select-Object Count, Name |
            Format-Table -AutoSize |
            Out-String |
            Set-Content (Join-Path $g7 "detections-by-node.txt")
    }
    else {
        "No falco-ref-* detections in strict window." |
            Set-Content (Join-Path $g7 "detections-overview.txt")
        "No falco-ref-* detections in strict window." |
            Set-Content (Join-Path $g7 "detections-summary.txt")
        "No falco-ref-* detections in strict window." |
            Set-Content (Join-Path $g7 "detections-by-node.txt")
    }

    return $detections
}


function Job-Complete {
    param([string]$Name)

    $raw = @(k get job $Name -n $namespace -o json 2>$null)
    if ($LASTEXITCODE -ne 0 -or $raw.Count -eq 0) { return $false }

    $j = ($raw -join "`n") | ConvertFrom-Json
    $complete = @(
        $j.status.conditions |
        Where-Object { $_.type -eq "Complete" -and $_.status -eq "True" }
    )

    ($complete.Count -gt 0 -and [int]$j.status.succeeded -ge 1)
}


function Convert-ToUtcDateTimeOffset {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    # PowerShell 7 may convert ISO-8601 JSON timestamps directly to DateTime.
    # Passing such an object to DateTimeOffset.Parse first converts it to a
    # culture-dependent string (e.g. 09/16/2026 ...), which fails under de-DE.
    if ($Value -is [DateTimeOffset]) {
        return $Value.ToUniversalTime()
    }

    if ($Value -is [DateTime]) {
        $dt = [DateTime]$Value

        if ($dt.Kind -eq [DateTimeKind]::Unspecified) {
            $dt = [DateTime]::SpecifyKind($dt, [DateTimeKind]::Utc)
        }
        else {
            $dt = $dt.ToUniversalTime()
        }

        return [DateTimeOffset]$dt
    }

    return [DateTimeOffset]::Parse(
        [string]$Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        (
            [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
            [System.Globalization.DateTimeStyles]::AdjustToUniversal
        )
    )
}


function Get-JobTiming {
    param([string]$Name)

    $raw = @(k get job $Name -n $namespace -o json 2>$null)

    if ($LASTEXITCODE -ne 0 -or $raw.Count -eq 0) {
        return $null
    }

    $j = ($raw -join "`n") | ConvertFrom-Json

    [PSCustomObject]@{
        Name           = $Name
        UID            = $j.metadata.uid
        CreationTime   = Convert-ToUtcDateTimeOffset $j.metadata.creationTimestamp
        StartTime      = Convert-ToUtcDateTimeOffset $j.status.startTime
        CompletionTime = Convert-ToUtcDateTimeOffset $j.status.completionTime
        Succeeded      = [int]$j.status.succeeded
    }
}


# ============================================================
# Resolve existing validated G7 script
# ============================================================

$scenario = Find-G7Script -ExplicitPath $ScenarioScript

Write-Host ""
Write-Host "Tracee G7 $Run"
Write-Host "Validated G7 script: $scenario"
Write-Host "Evidence directory: $g7"
Write-Host ""

$scenario | Set-Content (Join-Path $g7 "scenario-script-path.txt")
Copy-Item $scenario (Join-Path $g7 "validated-g7-scenario.ps1")
Copy-Item $PSCommandPath (Join-Path $g7 "tracee-g7-run.ps1")


# ============================================================
# Time sync + PRE state
# ============================================================

$sync = @()
foreach ($node in $nodes) {
    $v = (@(ssh $node "timedatectl show -p NTPSynchronized --value") -join "").Trim()
    if ($LASTEXITCODE -ne 0 -or $v -ne "yes") {
        throw "NTP synchronization not confirmed on $node."
    }
    $sync += [PSCustomObject]@{ Node=$node; NTPSynchronized=$v }
}

$sync |
    Format-Table -AutoSize |
    Out-String |
    Set-Content (Join-Path $g7 "cluster-time-sync.txt")


# ============================================================
# Reset G1-G3 Jobs before the measurement window
# ============================================================

$cleanupFile = Join-Path $g7 "pre-run-job-cleanup.txt"

$cleanupOutput = @(
    k delete job `
        g1-crud `
        g2-schema-migration `
        g3-backup `
        -n $namespace `
        --ignore-not-found=true `
        --wait=true `
        2>&1
)

$cleanupExit = $LASTEXITCODE

$cleanupOutput |
    Set-Content $cleanupFile

if ($cleanupExit -ne 0) {
    throw "Pre-run cleanup of G1-G3 Jobs failed. See pre-run-job-cleanup.txt."
}

foreach ($job in $jobs) {
    $null = k get job $job -n $namespace -o name 2>$null

    if ($LASTEXITCODE -eq 0) {
        throw "Pre-run cleanup failed: Job $job still exists."
    }
}

"All G1-G3 Jobs absent before START." |
    Add-Content $cleanupFile

# Keep cleanup clearly outside the START-2s collection margin.
Start-Sleep -Seconds 3

@"
Scenario: G7 combined benign workload
Implementation: existing validated G7 PowerShell script
Wrapper scope: one Tracee measurement window around that script
Included: G1, G2, G3, G4a, G5a, G5c, G6
Excluded: G4b
"@ | Set-Content (Join-Path $g7 "scenario-definition.txt")

@"
Tracee JSONL is parsed as JSON before sanitization.
Only values of sensitive environment entries are replaced with <redacted>;
argv/command strings are left structurally unchanged.
Each sanitized Tracee line is parsed again to verify that valid JSON is preserved.
Scenario output is sanitized for wsrep_sst_auth and common secret key=value patterns.
"@ | Set-Content (Join-Path $g7 "redaction-note.txt")

k get pods -A -o wide | Out-File (Join-Path $g7 "pre-all-pods.txt")
k get pods -n $namespace -o wide | Out-File (Join-Path $g7 "pre-database-pods.txt")
k get pods -n $traceeNamespace -o wide | Out-File (Join-Path $g7 "pre-tracee-pods.txt")
k get pod $targetPod -n $namespace -o yaml | Out-File (Join-Path $g7 "target-pod-pre.yaml")

$targetPre = Get-TargetPod
$targetPre | Format-List | Out-String | Set-Content (Join-Path $g7 "target-pod-pre.txt")
if ($targetPre.Phase -ne "Running" -or -not $targetPre.Ready) {
    throw "Target Pod is not Running and Ready before G7."
}

$traceePre = @(Get-TraceeAgents)
$traceePre | Sort-Object Node | Format-Table -AutoSize | Out-String |
    Set-Content (Join-Path $g7 "tracee-agents-pre.txt")

foreach ($node in $nodes) {
    $a = @($traceePre | Where-Object Node -eq $node)
    if ($a.Count -ne 1 -or $a[0].Phase -ne "Running") {
        throw "Tracee agent check failed on $node."
    }
}


# ============================================================
# Strict START -> validated G7 script -> END
# ============================================================

$startUtc = Get-ClusterUtc
$startUtc | Set-Content (Join-Path $g7 "start-utc.txt")

$scenarioOutput = Join-Path $g7 "scenario-output.txt"
New-Item -ItemType File -Force -Path $scenarioOutput | Out-Null

Write-Host "G7 START: $startUtc"

$scenarioSucceeded = $false
$scenarioError = $null

try {
    & $scenario *>&1 |
        ForEach-Object {
            $raw = [string]$_
            Write-Host $raw
            (Redact-ScenarioLine $raw) | Add-Content $scenarioOutput
        }

    $scenarioSucceeded = $true
}
catch {
    $scenarioError = $_.Exception.Message
    "G7 ERROR: $scenarioError" | Add-Content $scenarioOutput
    $scenarioError | Set-Content (Join-Path $g7 "scenario-error.txt")
}

if ($scenarioSucceeded) {
    "G7_EXIT_CODE=0" | Set-Content (Join-Path $g7 "exit-code.txt")
}
else {
    "G7_EXIT_CODE=1" | Set-Content (Join-Path $g7 "exit-code.txt")
}

$endUtc = Get-ClusterUtc
$endUtc | Set-Content (Join-Path $g7 "end-utc.txt")

@"
G7_START_UTC=$startUtc
G7_END_UTC=$endUtc
"@ | Set-Content (Join-Path $g7 "scenario-window.txt")

Write-Host "G7 END:   $endUtc"


# ============================================================
# Collect Tracee logs
# ============================================================

$startDto = [DateTimeOffset]::Parse($startUtc).ToUniversalTime()
$collectionStartUtc = $startDto.AddSeconds(-2).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$collectionStartUtc | Set-Content (Join-Path $g7 "collection-start-utc.txt")

Collect-Tracee -SinceTime $collectionStartUtc -Agents $traceePre


# ============================================================
# POST evidence
# ============================================================

k get pods -A -o wide | Out-File (Join-Path $g7 "post-all-pods.txt")
k get pods -n $namespace -o wide | Out-File (Join-Path $g7 "post-database-pods.txt")
k get pods -n $traceeNamespace -o wide | Out-File (Join-Path $g7 "post-tracee-pods.txt")

$targetPost = Get-TargetPod -AllowMissing
if ($targetPost) {
    k get pod $targetPod -n $namespace -o yaml | Out-File (Join-Path $g7 "target-pod-post.yaml")
    $targetPost | Format-List | Out-String | Set-Content (Join-Path $g7 "target-pod-post.txt")
}

foreach ($job in $jobs) {
    k get job $job -n $namespace -o yaml 2>$null | Out-File (Join-Path $g7 "$job-job.yaml")
    k logs -n $namespace "job/$job" 2>$null | Out-File (Join-Path $g7 "$job-job.log")
}

$traceePost = @(Get-TraceeAgents)
$traceePost | Sort-Object Node | Format-Table -AutoSize | Out-String |
    Set-Content (Join-Path $g7 "tracee-agents-post.txt")


# ============================================================
# Ground-truth validation
# ============================================================

$problems = @()
$text = Get-Content $scenarioOutput -Raw

if (-not $scenarioSucceeded) {
    $problems += "Validated G7 script did not complete successfully."
}

foreach ($marker in @(
    "G4a completed successfully",
    "G5a config read completed successfully",
    "G5c proc read completed successfully",
    "G6 Pod deletion and recovery completed successfully",
    "G7 combined benign workload completed successfully"
)) {
    if ($text -notmatch [regex]::Escape($marker)) {
        $problems += "Missing marker: $marker"
    }
}

$startCheck = [DateTimeOffset]::Parse($startUtc).ToUniversalTime()
$endCheck   = [DateTimeOffset]::Parse($endUtc).ToUniversalTime()

# Kubernetes timestamps are second-granular, while START/END include milliseconds.
# A one-second tolerance avoids rejecting a Job created within the same second as START.
$jobWindowStart = $startCheck.AddSeconds(-1)
$jobWindowEnd   = $endCheck.AddSeconds(1)

foreach ($job in $jobs) {
    if (-not (Job-Complete $job)) {
        $problems += "$job was not confirmed Complete."
        continue
    }

    if ($text -notmatch [regex]::Escape("job.batch/$job created")) {
        $problems += "$job was not confirmed as newly created in this G7 run."
    }

    $timing = Get-JobTiming $job

    if (-not $timing) {
        $problems += "$job timing information could not be read."
        continue
    }

    if (
        -not $timing.CreationTime -or
        $timing.CreationTime -lt $jobWindowStart -or
        $timing.CreationTime -gt $jobWindowEnd
    ) {
        $problems += "$job creation time is outside the current G7 window."
    }

    if (
        -not $timing.CompletionTime -or
        $timing.CompletionTime -lt $jobWindowStart -or
        $timing.CompletionTime -gt $jobWindowEnd
    ) {
        $problems += "$job completion time is outside the current G7 window."
    }
}

$oldMatches = [regex]::Matches($text,'(?m)^Old Pod UID:\s*([0-9a-fA-F-]+)\s*$')
$newMatches = [regex]::Matches($text,'(?m)^New Pod UID:\s*([0-9a-fA-F-]+)\s*$')

$oldUid = if ($oldMatches.Count) { $oldMatches[$oldMatches.Count-1].Groups[1].Value } else { $null }
$newUid = if ($newMatches.Count) { $newMatches[$newMatches.Count-1].Groups[1].Value } else { $null }

if (-not $oldUid) { $problems += "Old Pod UID not found in G7 output." }
if (-not $newUid) { $problems += "New Pod UID not found in G7 output." }
if ($oldUid -and $newUid -and $oldUid -eq $newUid) { $problems += "Old and new Pod UIDs are identical." }
if ($oldUid -and $oldUid -ne $targetPre.UID) { $problems += "G6 old UID differs from pre-G7 UID." }

if (-not $targetPost) {
    $problems += "Target Pod missing after G7."
}
else {
    if ($targetPost.Phase -ne "Running" -or -not $targetPost.Ready) {
        $problems += "Recreated Pod is not Running and Ready."
    }
    if ($newUid -and $targetPost.UID -ne $newUid) {
        $problems += "Final Pod UID differs from G6 new UID."
    }
}

$finalMarker = "=== Final Galera status after combined workload ==="
$idx = $text.LastIndexOf($finalMarker)

$finalOk = $false
if ($idx -ge 0) {
    $final = $text.Substring($idx)
    $finalOk = (
        $final -match '(?m)wsrep_cluster_size\s+3\s*$' -and
        $final -match '(?m)wsrep_local_state_comment\s+Synced\s*$'
    )
}
if (-not $finalOk) { $problems += "Final Galera 3/Synced not confirmed." }

if ($problems.Count -eq 0) {
    @"
G7 ground truth: OK
G1 Job Complete: CONFIRMED
G2 Job Complete: CONFIRMED
G3 Job Complete: CONFIRMED
G4a: CONFIRMED
G5a: CONFIRMED
G5c: CONFIRMED
G6 recovery: CONFIRMED
Old Pod UID: $oldUid
New Pod UID: $newUid
Pod UID changed: CONFIRMED
Recreated Pod Running and Ready: CONFIRMED
Final Galera cluster size 3: CONFIRMED
Final Galera local state Synced: CONFIRMED
Pre-G7 node: $($targetPre.Node)
Post-G7 node: $($targetPost.Node)
"@ | Set-Content (Join-Path $g7 "scenario-validation.txt")
}
else {
    @("G7 ground truth: CHECK REQUIRED") + $problems |
        Set-Content (Join-Path $g7 "scenario-validation.txt")
}


# ============================================================
# Tracee stability
# ============================================================

$stability = @()

foreach ($node in $nodes) {
    $before = $traceePre | Where-Object Node -eq $node | Select-Object -First 1
    $after  = $traceePost | Where-Object Node -eq $node | Select-Object -First 1

    if (-not $after) {
        $stability += "No Tracee agent after G7 on $node."
        continue
    }

    if ($before.Pod -ne $after.Pod) {
        $stability += "Tracee Pod changed on ${node}: $($before.Pod) -> $($after.Pod)"
    }
    if ($before.Restarts -ne $after.Restarts) {
        $stability += "Tracee restarts changed on ${node}: $($before.Restarts) -> $($after.Restarts)"
    }
    if ($after.Phase -ne "Running") {
        $stability += "Tracee agent on $node is not Running."
    }
}

if ($stability.Count -eq 0) {
    "Tracee agents stable during the run." |
        Set-Content (Join-Path $g7 "tracee-stability.txt")
}
else {
    $stability | Set-Content (Join-Path $g7 "tracee-stability.txt")
}


# ============================================================
# Exact strict-window filtering + detection summary
# ============================================================

$startNs = Iso-ToNs $startUtc
$endNs = Iso-ToNs $endUtc

foreach ($node in $nodes) {
    Filter-Window `
        -InputFile (Join-Path $g7 "$node-since-start.jsonl") `
        -OutputFile (Join-Path $g7 "$node-window.jsonl") `
        -StartNs $startNs `
        -EndNs $endNs
}

$detections = @(Build-DetectionSummary)


# ============================================================
# Run status
# ============================================================

$status = @(
    $(if ($scenarioSucceeded) { "G7 scenario script: COMPLETE" } else { "G7 scenario script: FAILED" }),
    $(if ($problems.Count -eq 0) { "G7 ground truth: OK" } else { "G7 ground truth: CHECK REQUIRED" }),
    $(if ($stability.Count -eq 0) { "Tracee stability: OK" } else { "Tracee stability: CHECK REQUIRED" }),
    "START: $startUtc",
    "END:   $endUtc",
    "Validated G7 script: $scenario",
    "Pre-G7 Pod UID: $($targetPre.UID)",
    "G6 old Pod UID: $oldUid",
    "G6 new Pod UID: $newUid",
    "Post-G7 Pod UID: $($targetPost.UID)",
    "Node: $($targetPre.Node) -> $($targetPost.Node)",
    "Tracee detections in strict window: $($detections.Count)"
)

$status | Set-Content (Join-Path $g7 "run-status.txt")

Write-Host ""
Write-Host "============================================"
Write-Host "G7 $Run finished"
Write-Host "============================================"
$status | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Evidence directory:"
Write-Host $g7

if (-not $scenarioSucceeded) {
    throw "G7 execution failed. See scenario-output.txt."
}
if ($problems.Count -gt 0) {
    throw "G7 ground-truth validation failed. See scenario-validation.txt."
}
if ($stability.Count -gt 0) {
    throw "Tracee stability failed. See tracee-stability.txt."
}

Write-Host "Run validity checks: OK"
