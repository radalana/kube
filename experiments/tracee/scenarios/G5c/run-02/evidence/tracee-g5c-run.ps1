param(
    [ValidateSet("run-01", "run-02", "run-03")]
    [string]$Run
)

# ============================================================
# Tracee G5c - /proc process and system information inspection
#
# Place this file at:
#   experiments\tracee\scenarios\G5c\tracee-g5c-run.ps1
#
# Run it from the repository root:
#   .\experiments\tracee\scenarios\G5c\tracee-g5c-run.ps1
#
# If -Run is omitted, the script automatically selects:
#   run-01 -> run-02 -> run-03
#
# G5c predefined operation:
#   /proc/1/cmdline
#   /proc/1/status
#   /proc/self/status
#   /proc/meminfo
#
# The strict START-END window contains only the predefined G5c
# operation. Tracee collection and validation are performed after END.
# ============================================================

$ErrorActionPreference = "Stop"

$namespace       = "database"
$targetPod       = "mariadb-galera-0"
$targetContainer = "mariadb"

$traceeNamespace = "tracee"
$nodes = @("master", "worker1", "worker2")

# Expected location:
# repo\experiments\tracee\scenarios\G5c\tracee-g5c-run.ps1
$repoRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..\..\..\..")
)

$g5Root = Join-Path `
    $repoRoot `
    "experiments\tracee\scenarios\G5c"

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
Write-Host "Tracee G5c $Run"
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

    # Tracee is configured with exec-env=true.
    # Mask common secret-bearing environment variables while preserving
    # timestamps, process data, matched policies, and attribution fields.
    return [regex]::Replace(
        $Line,
        '(?i)("[^"]*(?:PASSWORD|PASSWD|SECRET|TOKEN)[^"]*=)[^"]*"',
        '${1}<redacted>"'
    )
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
# 0. Verify time synchronization
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
    $PSCommandPath `
    (Join-Path $g5 "tracee-g5c-run.ps1") `
    -Force

@"
Variant: G5c
Target: namespace=$namespace pod=$targetPod container=$targetContainer
Execution: authorized non-interactive kubectl exec
Selected /proc files:
  /proc/1/cmdline
  /proc/1/status
  /proc/self/status
  /proc/meminfo
Validation: output for all four selected /proc files must be present and the command must complete successfully
"@ | Set-Content (Join-Path $g5 "scenario-definition.txt")

@'
kubectl exec -n database mariadb-galera-0 -c mariadb -- sh -c 'set -eu; echo "=== Hostname ==="; hostname; echo ""; echo "=== /proc/1/cmdline ==="; cat /proc/1/cmdline; echo ""; echo ""; echo "=== /proc/1/status ==="; cat /proc/1/status; echo ""; echo "=== /proc/self/status ==="; cat /proc/self/status; echo ""; echo "=== /proc/meminfo ==="; cat /proc/meminfo'
'@ | Set-Content (Join-Path $g5 "scenario-command.txt")

@"
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
    throw "Target Pod is not Running and Ready before G5c."
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
Write-Host "G5c START: $startUtc"
Write-Host ""


# ============================================================
# 3. Execute predefined G5c operation exactly once
# ============================================================

$scenarioSucceeded = $false
$scenarioError = $null
$scenarioExitCode = $null
$tempScenarioOutput = [System.IO.Path]::GetTempFileName()

try {
    # Use success-stream strings here rather than Write-Host so Tee-Object
    # writes these markers to scenario-output.txt as well as to the console.
    "Starting G5c: authorized /proc process inspection" |
        Tee-Object -FilePath $tempScenarioOutput

    "Target: namespace=database, pod=mariadb-galera-0, container=mariadb" |
        Tee-Object -FilePath $tempScenarioOutput -Append

    "" |
        Tee-Object -FilePath $tempScenarioOutput -Append

    k exec `
        -n $namespace `
        $targetPod `
        -c $targetContainer `
        -- sh -c 'set -eu; echo "=== Hostname ==="; hostname; echo ""; echo "=== /proc/1/cmdline ==="; cat /proc/1/cmdline; echo ""; echo ""; echo "=== /proc/1/status ==="; cat /proc/1/status; echo ""; echo "=== /proc/self/status ==="; cat /proc/self/status; echo ""; echo "=== /proc/meminfo ==="; cat /proc/meminfo' `
        2>&1 |
        Tee-Object -FilePath $tempScenarioOutput -Append

    $scenarioExitCode = $LASTEXITCODE

    if ($null -eq $scenarioExitCode) {
        $scenarioExitCode = 0
    }

    if ($scenarioExitCode -ne 0) {
        throw "G5c scenario returned exit code $scenarioExitCode."
    }

    "" |
        Tee-Object -FilePath $tempScenarioOutput -Append

    "G5c proc read completed successfully" |
        Tee-Object -FilePath $tempScenarioOutput -Append

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
        Copy-Item `
            $tempScenarioOutput `
            (Join-Path $g5 "scenario-output.txt") `
            -Force

        Remove-Item $tempScenarioOutput -Force
    }
}

"G5c_EXIT_CODE=$scenarioExitCode" |
    Set-Content (Join-Path $g5 "exit-code.txt")


# ============================================================
# 4. END strict scenario window immediately after G5c returns
# ============================================================

$endUtc = Get-ClusterUtc
$endUtc | Set-Content (Join-Path $g5 "end-utc.txt")

Write-Host ""
Write-Host "G5c END:   $endUtc"
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
    $targetProblems += "Target Pod UID changed during G5c."
}

if ($targetPost.Node -ne $targetPre.Node) {
    $targetProblems += "Target Pod node changed during G5c."
}

if ($targetPost.Phase -ne "Running" -or -not $targetPost.Ready) {
    $targetProblems += "Target Pod is not Running and Ready after G5c."
}

if ($targetPost.ContainerRestarts -ne $targetPre.ContainerRestarts) {
    $targetProblems += "Target container restart count changed during G5c."
}

if ($targetPost.ContainerID -ne $targetPre.ContainerID) {
    $targetProblems += "Target container ID changed during G5c."
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
        $stabilityProblems += "No Tracee agent found on $node after G5c."
        continue
    }

    if ($before.Pod -ne $after.Pod) {
        $stabilityProblems += "Tracee Pod changed on ${node}: $($before.Pod) -> $($after.Pod)"
    }

    if ($after.Restarts -ne $before.Restarts) {
        $stabilityProblems += "Tracee restart count changed on ${node}: $($before.Restarts) -> $($after.Restarts)"
    }

    if ($after.Phase -ne "Running") {
        $stabilityProblems += "Tracee agent on $node is not Running after G5c."
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
# 10. Ground-truth validation
# ============================================================

$groundTruthProblems = @()
$scenarioOutputFile = Join-Path $g5 "scenario-output.txt"

if (-not (Test-Path $scenarioOutputFile)) {
    $groundTruthProblems += "scenario-output.txt is missing."
}
else {
    $scenarioText = Get-Content $scenarioOutputFile -Raw

    foreach ($marker in @(
        "=== /proc/1/cmdline ===",
        "=== /proc/1/status ===",
        "=== /proc/self/status ===",
        "=== /proc/meminfo ==="
    )) {
        if ($scenarioText -notmatch [regex]::Escape($marker)) {
            $groundTruthProblems += "Output marker missing: $marker"
        }
    }

    if ($scenarioText -notmatch [regex]::Escape("G5c proc read completed successfully")) {
        $groundTruthProblems += "G5c completion marker was not found."
    }

    if ($scenarioText -notmatch "mariadbd") {
        $groundTruthProblems += "/proc/1/cmdline content did not confirm mariadbd."
    }

    if ($scenarioText -notmatch "(?m)^Name:\s+mariadbd\s*$") {
        $groundTruthProblems += "/proc/1/status did not confirm mariadbd."
    }

    if ($scenarioText -notmatch "(?m)^MemTotal:\s+") {
        $groundTruthProblems += "/proc/meminfo content was not confirmed."
    }
}

if (-not $scenarioSucceeded) {
    $groundTruthProblems += "The predefined G5c operation did not complete successfully."
}

if ($groundTruthProblems.Count -eq 0) {
    @"
G5c ground truth: OK
/proc/1/cmdline inspection: CONFIRMED
/proc/1/status inspection: CONFIRMED
/proc/self/status inspection: CONFIRMED
/proc/meminfo inspection: CONFIRMED
Predefined G5c operation completion: CONFIRMED
"@ | Set-Content (Join-Path $g5 "scenario-validation.txt")
}
else {
    @(
        "G5c ground truth: CHECK REQUIRED"
        $groundTruthProblems
    ) | Set-Content (Join-Path $g5 "scenario-validation.txt")
}


# ============================================================
# 11. Run status
# ============================================================

$runStatus = @()

if ($scenarioSucceeded) {
    $runStatus += "G5c scenario: COMPLETE"
}
else {
    $runStatus += "G5c scenario: FAILED"
}

if ($groundTruthProblems.Count -eq 0) {
    $runStatus += "G5c ground truth: OK"
}
else {
    $runStatus += "G5c ground truth: CHECK REQUIRED"
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
Write-Host "G5c $Run finished"
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
    throw "G5c scenario failed. See scenario-error.txt and scenario-output.txt."
}

if ($groundTruthProblems.Count -gt 0) {
    throw "G5c ground-truth validation failed. See scenario-validation.txt."
}

if ($targetProblems.Count -gt 0) {
    throw "Target Pod stability check failed. See target-pod-stability.txt."
}

if ($stabilityProblems.Count -gt 0) {
    throw "Tracee stability check failed. See tracee-stability.txt."
}

Write-Host "Run validity checks: OK"
