param(
    [ValidateSet("run-01", "run-02", "run-03")]
    [string]$Run
)

# ============================================================
# Tracee G5a - MariaDB configuration file inspection
#
# Place this file at:
#   experiments\tracee\scenarios\G5a\tracee-g5a-run.ps1
#
# Run it from the repository root:
#   .\experiments\tracee\scenarios\G5a\tracee-g5a-run.ps1
#
# If -Run is omitted, the script automatically selects the first
# missing run directory in this order:
#   run-01 -> run-02 -> run-03
#
# Formal scenario:
#   tests\scenarios\G5-file-process-inspection\run-g5a-config-read.ps1
#
# The measured window contains ONLY the predefined G5a scenario.
# Tracee collection, validation, and post-state checks are performed
# outside the strict START-END window.
# ============================================================

$ErrorActionPreference = "Stop"

$namespace       = "database"
$targetPod       = "mariadb-galera-0"
$targetContainer = "mariadb"

$traceeNamespace = "tracee"
$nodes = @("master", "worker1", "worker2")

# Expected location of this wrapper:
# repo\experiments\tracee\scenarios\G5a\tracee-g5a-run.ps1
$repoRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..\..\..\..")
)

$scenarioScript = Join-Path `
    $repoRoot `
    "tests\scenarios\G5-file-process-inspection\run-g5a-config-read.ps1"

$g5Root = Join-Path `
    $repoRoot `
    "experiments\tracee\scenarios\G5a"

if (-not (Test-Path $scenarioScript)) {
    throw "Scenario script not found: $scenarioScript"
}

New-Item -ItemType Directory -Force -Path $g5Root | Out-Null

if (-not $Run) {
    foreach ($candidate in @("run-01", "run-02", "run-03")) {
        if (-not (Test-Path (Join-Path $g5Root $candidate))) {
            $Run = $candidate
            break
        }
    }

    if (-not $Run) {
        throw "run-01, run-02, and run-03 already exist under $g5Root."
    }
}

$g5 = Join-Path $g5Root $Run

if (Test-Path $g5) {
    throw "Evidence directory already exists: $g5. Rename/remove it or choose another run."
}

New-Item -ItemType Directory -Force -Path $g5 | Out-Null

Write-Host ""
Write-Host "============================================"
Write-Host "Tracee G5a $Run"
Write-Host "============================================"
Write-Host "Evidence directory:"
Write-Host $g5
Write-Host ""


# ============================================================
# Helper functions
# ============================================================

function Get-TraceeAgents {
    $items = (k get pods -n $traceeNamespace -o json | ConvertFrom-Json).items

    foreach ($item in $items) {
        if (
            $item.metadata.name -like "tracee-*" -and
            $item.metadata.name -notlike "tracee-operator*" -and
            $nodes -contains $item.spec.nodeName
        ) {
            $restarts = 0

            if ($item.status.containerStatuses) {
                $sum = (
                    $item.status.containerStatuses |
                    Measure-Object -Property restartCount -Sum
                ).Sum

                if ($null -ne $sum) {
                    $restarts = [int]$sum
                }
            }

            [PSCustomObject]@{
                Node     = $item.spec.nodeName
                Pod      = $item.metadata.name
                Phase    = $item.status.phase
                Restarts = $restarts
            }
        }
    }
}


function Get-TargetPodSnapshot {
    $podObject = (
        k get pod $targetPod -n $namespace -o json |
        ConvertFrom-Json
    )

    if ($LASTEXITCODE -ne 0 -or -not $podObject) {
        throw "Could not read target Pod $targetPod."
    }

    $readyCondition = (
        $podObject.status.conditions |
        Where-Object type -eq "Ready" |
        Select-Object -First 1
    )

    $containerStatus = (
        $podObject.status.containerStatuses |
        Where-Object name -eq $targetContainer |
        Select-Object -First 1
    )

    if (-not $containerStatus) {
        throw "Container $targetContainer not found in Pod $targetPod."
    }

    [PSCustomObject]@{
        Pod               = $podObject.metadata.name
        UID               = $podObject.metadata.uid
        Node              = $podObject.spec.nodeName
        Phase             = $podObject.status.phase
        Ready             = ($readyCondition.status -eq "True")
        Container         = $containerStatus.name
        ContainerID       = $containerStatus.containerID
        ContainerRestarts = [int]$containerStatus.restartCount
    }
}


function Get-ClusterUtc {
    # Formal scenario boundaries always use the master node clock.
    $remoteOutput = @(ssh master "date -u +%s%N")
    $sshExit = $LASTEXITCODE

    if ($sshExit -ne 0) {
        throw "Could not obtain UTC timestamp from master."
    }

    $remoteNsRaw = ($remoteOutput -join "").Trim()

    if ($remoteNsRaw -notmatch '^\d+$') {
        throw "Unexpected timestamp returned by master: $remoteNsRaw"
    }

    $remoteNs = [decimal]$remoteNsRaw
    $remoteMs = [Int64][decimal]::Floor($remoteNs / 1000000)

    return (
        [DateTimeOffset]::FromUnixTimeMilliseconds($remoteMs)
    ).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}


function Convert-IsoToDateTimeOffset {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Timestamp
    )

    return [DateTimeOffset]::Parse(
        $Timestamp,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal
    ).ToUniversalTime()
}


function Convert-IsoToUnixNs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Timestamp
    )

    $dto = Convert-IsoToDateTimeOffset $Timestamp
    $epochTicks = [DateTimeOffset]::UnixEpoch.UtcDateTime.Ticks

    return [Int64](($dto.UtcDateTime.Ticks - $epochTicks) * 100)
}


function Redact-TraceeLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    # Tracee is configured with exec-env=true. Mask common secret-bearing
    # environment variables while preserving the event structure.
    return [regex]::Replace(
        $Line,
        '(?i)("[^"]*(?:PASSWORD|PASSWD|SECRET|TOKEN)[^"]*=)[^"]*"',
        '${1}<redacted>"'
    )
}


function Redact-G5aScenarioOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputFile,

        [Parameter(Mandatory = $true)]
        [string]$OutputFile
    )

    $result = @(
        foreach ($line in Get-Content $InputFile) {
            if (
                $line -notmatch '^\s*[#;]' -and
                $line -match '^(?<prefix>\s*[^=]*(?:wsrep_sst_auth|password|passwd|secret|token)[^=]*=).*$'
            ) {
                "$($Matches.prefix)<redacted>"
            }
            else {
                $line
            }
        }
    )

    $result | Set-Content -Path $OutputFile -Encoding utf8
}


function Collect-TraceeLogs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionStartUtc,

        [Parameter(Mandatory = $true)]
        [array]$TraceePre
    )

    foreach ($node in $nodes) {
        $agent = $TraceePre |
            Where-Object Node -eq $node |
            Select-Object -First 1

        if (-not $agent) {
            throw "No Tracee agent found on $node."
        }

        $pod = $agent.Pod
        $logFile   = Join-Path $g5 "$node-since-start.jsonl"
        $errorFile = Join-Path $g5 "$node-tracee-log-errors.txt"

        Write-Host "Collecting Tracee output: $node -> $pod"

        New-Item -ItemType File -Force -Path $logFile | Out-Null

        $output = @(
            k logs `
                -n $traceeNamespace `
                $pod `
                --since-time=$CollectionStartUtc `
                2> $errorFile
        )

        $logExit = $LASTEXITCODE

        if ($logExit -ne 0) {
            throw "Could not collect Tracee logs from ${node}. See $errorFile"
        }

        if ($output.Count -gt 0) {
            $output |
                ForEach-Object { Redact-TraceeLine ([string]$_) } |
                Set-Content -Path $logFile -Encoding utf8
        }

        Write-Host "${node}: $($output.Count) lines collected"
    }
}


function Filter-TraceeWindow {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputFile,

        [Parameter(Mandatory = $true)]
        [string]$OutputFile,

        [Parameter(Mandatory = $true)]
        [Int64]$StartNs,

        [Parameter(Mandatory = $true)]
        [Int64]$EndNs
    )

    New-Item -ItemType File -Force -Path $OutputFile | Out-Null

    if (-not (Test-Path $InputFile)) {
        return
    }

    $selected = @(
        foreach ($line in Get-Content $InputFile) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            try {
                $event = $line | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                # Ignore non-JSON Tracee diagnostic lines.
                continue
            }

            if ($null -eq $event.timestamp) {
                continue
            }

            $ts = [Int64]$event.timestamp

            if ($ts -ge $StartNs -and $ts -le $EndNs) {
                $line
            }
        }
    )

    if ($selected.Count -gt 0) {
        $selected | Set-Content -Path $OutputFile -Encoding utf8
    }
}


function Build-DetectionOverview {
    $detections = @()

    foreach ($node in $nodes) {
        $file = Join-Path $g5 "$node-window.jsonl"

        if (-not (Test-Path $file)) {
            continue
        }

        foreach ($line in Get-Content $file) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            try {
                $event = $line | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                continue
            }

            $falcoRefPolicies = @(
                $event.matchedPolicies |
                Where-Object { $_ -like "falco-ref-*" }
            )

            if ($falcoRefPolicies.Count -eq 0) {
                continue
            }

            $detections += [PSCustomObject]@{
                Node      = $node
                Timestamp = $event.timestamp
                Event     = $event.eventName
                Process   = $event.processName
                PID       = $event.processId
                Policies  = ($falcoRefPolicies -join ", ")
            }
        }
    }

    $overviewFile = Join-Path $g5 "detections-overview.txt"
    $summaryFile  = Join-Path $g5 "detections-summary.txt"

    if ($detections.Count -gt 0) {
        $detections |
            Format-Table -AutoSize |
            Out-String -Width 300 |
            Set-Content $overviewFile

        $detections |
            Group-Object Policies |
            Sort-Object Count -Descending |
            Select-Object Count, Name |
            Format-Table -AutoSize |
            Out-String |
            Set-Content $summaryFile
    }
    else {
        "No falco-ref-* matched policy events in the strict scenario window." |
            Set-Content $overviewFile

        "No falco-ref-* matched policy events in the strict scenario window." |
            Set-Content $summaryFile
    }

    return $detections
}


# ============================================================
# 0. Verify NTP synchronization
# ============================================================

$timeSyncStatus = @()
$timeSyncProblems = @()

foreach ($node in $nodes) {
    $ntpOutput = @(ssh $node "timedatectl show -p NTPSynchronized --value")
    $sshExit = $LASTEXITCODE

    if ($sshExit -ne 0) {
        $timeSyncProblems += "Could not check time synchronization on $node."
        continue
    }

    $ntp = ($ntpOutput -join "").Trim().ToLowerInvariant()

    $timeSyncStatus += [PSCustomObject]@{
        Node            = $node
        NTPSynchronized = $ntp
    }

    if ($ntp -ne "yes") {
        $timeSyncProblems += "NTP synchronization is not confirmed on $node."
    }
}

$timeSyncStatus |
    Format-Table -AutoSize |
    Out-String |
    Set-Content (Join-Path $g5 "cluster-time-sync.txt")

Write-Host "Cluster time synchronization:"
$timeSyncStatus | Format-Table -AutoSize

if ($timeSyncProblems.Count -gt 0) {
    $timeSyncProblems |
        Add-Content (Join-Path $g5 "cluster-time-sync.txt")

    throw "Cluster node time synchronization check failed."
}


# ============================================================
# 1. Save scenario definition and PRE state
# ============================================================

Copy-Item `
    $scenarioScript `
    (Join-Path $g5 "run-g5a-config-read.ps1") `
    -Force

Copy-Item `
    $PSCommandPath `
    (Join-Path $g5 "tracee-g5a-run.ps1") `
    -Force

@"
Variant: G5a
Target: namespace=$namespace pod=$targetPod container=$targetContainer
Execution: authorized non-interactive kubectl exec through the predefined G5a script
Selected files:
  /etc/mysql/mariadb.cnf
  /etc/mysql/mariadb.conf.d/0-galera.cnf
Validation: both selected file sections must be present in scenario output and the predefined script must complete successfully
"@ | Set-Content (Join-Path $g5 "scenario-definition.txt")

@"
Sensitive values are redacted from scenario-output.txt.
Common secret-bearing environment variables are redacted from collected Tracee JSONL files.
Redaction changes secret values only and does not alter timestamps, event names, process fields, container IDs, or matched policy names.
"@ | Set-Content (Join-Path $g5 "redaction-note.txt")

k get pods -A -o wide |
    Out-File (Join-Path $g5 "pre-all-pods.txt")

k get pods -n $namespace -o wide |
    Out-File (Join-Path $g5 "pre-database-pods.txt")

k get pods -n $traceeNamespace -o wide |
    Out-File (Join-Path $g5 "pre-tracee-pods.txt")

k get pod $targetPod -n $namespace -o yaml |
    Out-File (Join-Path $g5 "target-pod-pre.yaml")

$targetPre = Get-TargetPodSnapshot

$targetPre |
    Format-List |
    Out-String |
    Set-Content (Join-Path $g5 "target-pod-pre.txt")

if ($targetPre.Phase -ne "Running" -or -not $targetPre.Ready) {
    throw "Target Pod is not Running and Ready before G5a."
}

$traceePre = @(Get-TraceeAgents)

$traceePre |
    Sort-Object Node |
    Format-Table -AutoSize |
    Out-String |
    Set-Content (Join-Path $g5 "tracee-agents-pre.txt")

foreach ($node in $nodes) {
    $agent = @($traceePre | Where-Object Node -eq $node)

    if ($agent.Count -ne 1) {
        throw "Expected exactly one Tracee agent on $node, found $($agent.Count)."
    }

    if ($agent[0].Phase -ne "Running") {
        throw "Tracee agent on $node is not Running."
    }
}


# ============================================================
# 2. START strict scenario window
# ============================================================

$startUtc = Get-ClusterUtc
$startUtc | Set-Content (Join-Path $g5 "start-utc.txt")

Write-Host ""
Write-Host "G5a START: $startUtc"
Write-Host ""


# ============================================================
# 3. Execute the predefined G5a scenario once
# ============================================================

$scenarioSucceeded = $false
$scenarioError = $null
$scenarioExitCode = $null
$tempScenarioOutput = [System.IO.Path]::GetTempFileName()

try {
    & $scenarioScript *>&1 |
        Tee-Object -FilePath $tempScenarioOutput

    $scenarioExitCode = $LASTEXITCODE

    if ($null -eq $scenarioExitCode) {
        $scenarioExitCode = 0
    }

    if ($scenarioExitCode -ne 0) {
        throw "G5a scenario returned exit code $scenarioExitCode."
    }

    $scenarioSucceeded = $true
}
catch {
    $scenarioError = $_.Exception.Message
    $scenarioError |
        Set-Content (Join-Path $g5 "scenario-error.txt")

    if ($null -eq $scenarioExitCode) {
        if ($null -ne $LASTEXITCODE) {
            $scenarioExitCode = $LASTEXITCODE
        }
        else {
            $scenarioExitCode = 1
        }
    }
}
finally {
    if (Test-Path $tempScenarioOutput) {
        Redact-G5aScenarioOutput `
            -InputFile $tempScenarioOutput `
            -OutputFile (Join-Path $g5 "scenario-output.txt")

        Remove-Item $tempScenarioOutput -Force
    }
}

" G5a_EXIT_CODE=$scenarioExitCode".Trim() |
    Set-Content (Join-Path $g5 "exit-code.txt")


# ============================================================
# 4. END strict scenario window immediately after G5a returns
# ============================================================

$endUtc = Get-ClusterUtc
$endUtc | Set-Content (Join-Path $g5 "end-utc.txt")

Write-Host ""
Write-Host "G5a END:   $endUtc"
Write-Host ""


# ============================================================
# 5. Collect Tracee logs
# ============================================================

$collectionStartUtc = (
    (Convert-IsoToDateTimeOffset $startUtc).AddSeconds(-2)
).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

$collectionStartUtc |
    Set-Content (Join-Path $g5 "collection-start-utc.txt")

Collect-TraceeLogs `
    -CollectionStartUtc $collectionStartUtc `
    -TraceePre $traceePre


# ============================================================
# 6. Save POST state
# ============================================================

k get pods -A -o wide |
    Out-File (Join-Path $g5 "post-all-pods.txt")

k get pods -n $namespace -o wide |
    Out-File (Join-Path $g5 "post-database-pods.txt")

k get pods -n $traceeNamespace -o wide |
    Out-File (Join-Path $g5 "post-tracee-pods.txt")

k get pod $targetPod -n $namespace -o yaml |
    Out-File (Join-Path $g5 "target-pod-post.yaml")

$targetPost = Get-TargetPodSnapshot

$targetPost |
    Format-List |
    Out-String |
    Set-Content (Join-Path $g5 "target-pod-post.txt")

$traceePost = @(Get-TraceeAgents)

$traceePost |
    Sort-Object Node |
    Format-Table -AutoSize |
    Out-String |
    Set-Content (Join-Path $g5 "tracee-agents-post.txt")


# ============================================================
# 7. Validate target Pod and Tracee stability
# ============================================================

$targetProblems = @()

if ($targetPost.UID -ne $targetPre.UID) {
    $targetProblems += "Target Pod UID changed during G5a."
}

if ($targetPost.Node -ne $targetPre.Node) {
    $targetProblems += "Target Pod node changed during G5a."
}

if ($targetPost.Phase -ne "Running" -or -not $targetPost.Ready) {
    $targetProblems += "Target Pod is not Running and Ready after G5a."
}

if ($targetPost.ContainerRestarts -ne $targetPre.ContainerRestarts) {
    $targetProblems += "Target container restart count changed during G5a."
}

if ($targetPost.ContainerID -ne $targetPre.ContainerID) {
    $targetProblems += "Target container ID changed during G5a."
}

if ($targetProblems.Count -eq 0) {
    "Target Pod remained stable during the run." |
        Set-Content (Join-Path $g5 "target-pod-stability.txt")
}
else {
    $targetProblems |
        Set-Content (Join-Path $g5 "target-pod-stability.txt")
}


$stabilityProblems = @()

foreach ($node in $nodes) {
    $before = $traceePre |
        Where-Object Node -eq $node |
        Select-Object -First 1

    $after = $traceePost |
        Where-Object Node -eq $node |
        Select-Object -First 1

    if (-not $after) {
        $stabilityProblems += "No Tracee agent found on $node after G5a."
        continue
    }

    if ($before.Pod -ne $after.Pod) {
        $stabilityProblems += "Tracee Pod changed on ${node}: $($before.Pod) -> $($after.Pod)"
    }

    if ($after.Restarts -ne $before.Restarts) {
        $stabilityProblems += "Tracee restart count changed on ${node}: $($before.Restarts) -> $($after.Restarts)"
    }

    if ($after.Phase -ne "Running") {
        $stabilityProblems += "Tracee agent on $node is not Running after G5a."
    }
}

if ($stabilityProblems.Count -eq 0) {
    "Tracee agents stable during the run." |
        Set-Content (Join-Path $g5 "tracee-stability.txt")
}
else {
    $stabilityProblems |
        Set-Content (Join-Path $g5 "tracee-stability.txt")
}


# ============================================================
# 8. Strict START-END filtering
# ============================================================

$startNs = Convert-IsoToUnixNs $startUtc
$endNs   = Convert-IsoToUnixNs $endUtc

foreach ($node in $nodes) {
    Filter-TraceeWindow `
        -InputFile (Join-Path $g5 "$node-since-start.jsonl") `
        -OutputFile (Join-Path $g5 "$node-window.jsonl") `
        -StartNs $startNs `
        -EndNs $endNs
}


# ============================================================
# 9. Build detection overview
# ============================================================

$detections = @(Build-DetectionOverview)


# ============================================================
# 10. Ground-truth validation from scenario output
# ============================================================

$groundTruthProblems = @()
$scenarioOutputFile = Join-Path $g5 "scenario-output.txt"

if (-not (Test-Path $scenarioOutputFile)) {
    $groundTruthProblems += "scenario-output.txt is missing."
}
else {
    $scenarioText = Get-Content $scenarioOutputFile -Raw

    if ($scenarioText -notmatch [regex]::Escape("--- /etc/mysql/mariadb.cnf ---")) {
        $groundTruthProblems += "Output for /etc/mysql/mariadb.cnf was not confirmed."
    }

    if ($scenarioText -notmatch [regex]::Escape("--- /etc/mysql/mariadb.conf.d/0-galera.cnf ---")) {
        $groundTruthProblems += "Output for /etc/mysql/mariadb.conf.d/0-galera.cnf was not confirmed."
    }

    if ($scenarioText -notmatch [regex]::Escape("G5a config read completed successfully")) {
        $groundTruthProblems += "G5a completion marker was not found."
    }
}

if (-not $scenarioSucceeded) {
    $groundTruthProblems += "The predefined G5a script did not complete successfully."
}

if ($groundTruthProblems.Count -eq 0) {
    @"
G5a ground truth: OK
/etc/mysql/mariadb.cnf inspection: CONFIRMED
/etc/mysql/mariadb.conf.d/0-galera.cnf inspection: CONFIRMED
Predefined G5a script completion: CONFIRMED
"@ | Set-Content (Join-Path $g5 "scenario-validation.txt")
}
else {
    @(
        "G5a ground truth: CHECK REQUIRED"
        $groundTruthProblems
    ) | Set-Content (Join-Path $g5 "scenario-validation.txt")
}


# ============================================================
# 11. Run status
# ============================================================

$runStatus = @()

if ($scenarioSucceeded) {
    $runStatus += "G5a scenario: COMPLETE"
}
else {
    $runStatus += "G5a scenario: FAILED"
}

if ($groundTruthProblems.Count -eq 0) {
    $runStatus += "G5a ground truth: OK"
}
else {
    $runStatus += "G5a ground truth: CHECK REQUIRED"
}

if ($targetProblems.Count -eq 0) {
    $runStatus += "Target Pod stability: OK"
}
else {
    $runStatus += "Target Pod stability: CHECK REQUIRED"
}

if ($stabilityProblems.Count -eq 0) {
    $runStatus += "Tracee stability: OK"
}
else {
    $runStatus += "Tracee stability: CHECK REQUIRED"
}

$runStatus += "START: $startUtc"
$runStatus += "END:   $endUtc"
$runStatus += "Target node: $($targetPre.Node)"
$runStatus += "Tracee detections in strict window: $($detections.Count)"

$runStatus |
    Set-Content (Join-Path $g5 "run-status.txt")


# ============================================================
# 12. Console summary
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host "G5a $Run finished"
Write-Host "============================================"
Write-Host "START: $startUtc"
Write-Host "END:   $endUtc"
Write-Host "Target Pod: $targetPod"
Write-Host "Target Node: $($targetPre.Node)"
Write-Host ""

if ($groundTruthProblems.Count -eq 0) {
    Write-Host "Ground truth: OK"
}
else {
    Write-Host "Ground truth: CHECK REQUIRED"
}

Write-Host ""
Write-Host "Tracee detections in strict window:"
Write-Host ""

if ($detections.Count -gt 0) {
    $detections |
        Format-Table Node, Event, Process, PID, Policies -AutoSize
}
else {
    Write-Host "No falco-ref-* matched-policy detections."
}

Write-Host ""
Write-Host "Evidence directory:"
Write-Host $g5
Write-Host ""


# ============================================================
# Final validity checks
# ============================================================

if (-not $scenarioSucceeded) {
    throw "G5a scenario failed. See scenario-error.txt and scenario-output.txt."
}

if ($groundTruthProblems.Count -gt 0) {
    throw "G5a ground-truth validation failed. See scenario-validation.txt."
}

if ($targetProblems.Count -gt 0) {
    throw "Target Pod stability check failed. See target-pod-stability.txt."
}

if ($stabilityProblems.Count -gt 0) {
    throw "Tracee stability check failed. See tracee-stability.txt."
}

Write-Host "Run validity checks: OK"
