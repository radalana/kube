param(
    [ValidateSet("run-01", "run-02", "run-03")]
    [string]$Run
)

# ============================================================
# Tracee G6 - Pod deletion and recovery
#
# Place this file at:
#   experiments\tracee\scenarios\G6\tracee-g6-run.ps1
#
# Run from the repository root:
#   .\experiments\tracee\scenarios\G6\tracee-g6-run.ps1
#
# If -Run is omitted, the first missing run directory is selected:
#   run-01 -> run-02 -> run-03
#
# The strict START-END window reproduces the G6 operation:
#   1. record target Pod state
#   2. query Galera state
#   3. record old Pod UID
#   4. delete mariadb-galera-0
#   5. wait for a new Pod with a different UID
#   6. wait until the recreated Pod is Ready
#   7. record new Pod state
#   8. query Galera state again
#
# Tracee output is collected from all three nodes because the recreated
# Pod may theoretically be scheduled to another node.
# ============================================================

$ErrorActionPreference = "Stop"

$namespace       = "database"
$targetPod       = "mariadb-galera-0"
$targetContainer = "mariadb"

$traceeNamespace = "tracee"
$nodes = @("master", "worker1", "worker2")

# Expected script location:
# repo\experiments\tracee\scenarios\G6\tracee-g6-run.ps1
$repoRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..\..\..\..")
)

$g6Root = Join-Path $repoRoot "experiments\tracee\scenarios\G6"
New-Item -ItemType Directory -Force -Path $g6Root | Out-Null

if (-not $Run) {
    foreach ($candidate in @("run-01", "run-02", "run-03")) {
        if (-not (Test-Path (Join-Path $g6Root $candidate))) {
            $Run = $candidate
            break
        }
    }

    if (-not $Run) {
        throw "run-01, run-02, and run-03 already exist under $g6Root."
    }
}

$g6 = Join-Path $g6Root $Run

if (Test-Path $g6) {
    throw "Evidence directory already exists: $g6. Rename/remove it or choose another run."
}

New-Item -ItemType Directory -Force -Path $g6 | Out-Null

Write-Host ""
Write-Host "============================================"
Write-Host "Tracee G6 $Run"
Write-Host "============================================"
Write-Host "Evidence directory:"
Write-Host $g6
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
    param(
        [switch]$AllowMissing
    )

    $json = @(
        k get pod $targetPod -n $namespace -o json 2>$null
    )
    $exit = $LASTEXITCODE

    if ($exit -ne 0 -or $json.Count -eq 0) {
        if ($AllowMissing) {
            return $null
        }

        throw "Could not read target Pod $targetPod."
    }

    $podObject = ($json -join "`n") | ConvertFrom-Json

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

    [PSCustomObject]@{
        Pod               = $podObject.metadata.name
        UID               = $podObject.metadata.uid
        Node              = $podObject.spec.nodeName
        Phase             = $podObject.status.phase
        Ready             = ($readyCondition.status -eq "True")
        Container         = $targetContainer
        ContainerID       = if ($containerStatus) { $containerStatus.containerID } else { $null }
        ContainerRestarts = if ($containerStatus) { [int]$containerStatus.restartCount } else { $null }
        PodIP             = $podObject.status.podIP
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
    # attribution-relevant fields.
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
        $logFile   = Join-Path $g6 "$node-since-start.jsonl"
        $errorFile = Join-Path $g6 "$node-tracee-log-errors.txt"

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
        $file = Join-Path $g6 "$node-window.jsonl"

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

            $containerId = ""
            if ($event.containerId) {
                $containerId = [string]$event.containerId
            }

            $detections += [PSCustomObject]@{
                Node        = $node
                Timestamp   = $event.timestamp
                Event       = $event.eventName
                Process     = $event.processName
                PID         = $event.processId
                ContainerID = $containerId
                Policies    = ($falcoRefPolicies -join ", ")
            }
        }
    }

    $overviewFile = Join-Path $g6 "detections-overview.txt"
    $summaryFile  = Join-Path $g6 "detections-summary.txt"

    if ($detections.Count -gt 0) {
        $detections |
            Format-Table -AutoSize |
            Out-String -Width 350 |
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


function Invoke-GaleraStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputFile,

        [Parameter(Mandatory = $true)]
        [string]$ScenarioOutputFile
    )

    $sql = @"
SHOW STATUS LIKE 'wsrep_cluster_size';
SHOW STATUS LIKE 'wsrep_local_state_comment';
"@

    $result = @(
        $sql |
            k exec -i `
                -n $namespace `
                $targetPod `
                -c $targetContainer `
                -- sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"' `
                2>&1
    )

    $exit = $LASTEXITCODE

    $result | Set-Content $OutputFile
    $result | Add-Content $ScenarioOutputFile

    foreach ($line in $result) {
        Write-Host $line
    }

    if ($exit -ne 0) {
        throw "Galera status query failed with exit code $exit."
    }

    return ($result -join "`n")
}


function Test-GaleraHealthy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $hasSize = $Text -match '(?m)wsrep_cluster_size\s+3\s*$'
    $hasSynced = $Text -match '(?m)wsrep_local_state_comment\s+Synced\s*$'

    return ($hasSize -and $hasSynced)
}


# ============================================================
# 0. Verify node time synchronization
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
    Set-Content (Join-Path $g6 "cluster-time-sync.txt")

Write-Host "Cluster time synchronization:"
$timeSyncStatus | Format-Table -AutoSize

if ($timeSyncProblems.Count -gt 0) {
    $timeSyncProblems |
        Add-Content (Join-Path $g6 "cluster-time-sync.txt")

    throw "Cluster node time synchronization check failed."
}


# ============================================================
# 1. Save definition and PRE tool/workload state
# ============================================================

Copy-Item `
    $PSCommandPath `
    (Join-Path $g6 "tracee-g6-run.ps1") `
    -Force

@"
Scenario: G6 Pod deletion and recovery
Target: namespace=$namespace pod=$targetPod container=$targetContainer

Operation inside the strict scenario window:
1. Record the state of mariadb-galera-0.
2. Query wsrep_cluster_size and wsrep_local_state_comment.
3. Record the old Pod UID.
4. Delete mariadb-galera-0.
5. Wait for a new Pod object with a different UID.
6. Wait until the recreated Pod becomes Ready.
7. Record the state of the recreated Pod.
8. Query wsrep_cluster_size and wsrep_local_state_comment again.

Validation:
- old and new Pod UIDs differ
- recreated Pod is Running and Ready
- Galera cluster size is 3 before and after recovery
- Galera local state is Synced before and after recovery
- Tracee agents remain stable
"@ | Set-Content (Join-Path $g6 "scenario-definition.txt")

@"
Common secret-bearing environment variables are redacted from collected Tracee JSONL files.
Redaction changes secret values only and does not alter timestamps, event names, process fields, container IDs, or matched policy names.
"@ | Set-Content (Join-Path $g6 "redaction-note.txt")

k get pods -A -o wide |
    Out-File (Join-Path $g6 "pre-all-pods.txt")

k get pods -n $namespace -o wide |
    Out-File (Join-Path $g6 "pre-database-pods.txt")

k get pods -n $traceeNamespace -o wide |
    Out-File (Join-Path $g6 "pre-tracee-pods.txt")

k get pod $targetPod -n $namespace -o yaml |
    Out-File (Join-Path $g6 "target-pod-pre.yaml")

$targetPre = Get-TargetPodSnapshot

$targetPre |
    Format-List |
    Out-String |
    Set-Content (Join-Path $g6 "target-pod-pre.txt")

if ($targetPre.Phase -ne "Running" -or -not $targetPre.Ready) {
    throw "Target Pod is not Running and Ready before G6."
}

$traceePre = @(Get-TraceeAgents)

$traceePre |
    Sort-Object Node |
    Format-Table -AutoSize |
    Out-String |
    Set-Content (Join-Path $g6 "tracee-agents-pre.txt")

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
$startUtc | Set-Content (Join-Path $g6 "start-utc.txt")

$scenarioOutput = Join-Path $g6 "scenario-output.txt"
New-Item -ItemType File -Force -Path $scenarioOutput | Out-Null

Write-Host ""
Write-Host "G6 START: $startUtc"
Write-Host ""


# ============================================================
# 3. Execute predefined G6 operation
# ============================================================

$scenarioSucceeded = $false
$scenarioError = $null
$scenarioExitCode = 0

$oldUid = $null
$newUid = $null

$preGaleraText = ""
$postGaleraText = ""

try {
    "=== State before Pod deletion ===" |
        Tee-Object -FilePath $scenarioOutput -Append

    k get pod $targetPod -n $namespace -o wide 2>&1 |
        Tee-Object -FilePath $scenarioOutput -Append

    if ($LASTEXITCODE -ne 0) {
        throw "Could not record target Pod state before deletion."
    }

    "" | Tee-Object -FilePath $scenarioOutput -Append

    "=== Galera status before Pod deletion ===" |
        Tee-Object -FilePath $scenarioOutput -Append

    $preGaleraText = Invoke-GaleraStatus `
        -OutputFile (Join-Path $g6 "pre-galera.txt") `
        -ScenarioOutputFile $scenarioOutput

    if (-not (Test-GaleraHealthy $preGaleraText)) {
        throw "Galera was not size=3 and Synced before deletion."
    }

    $oldUid = $targetPre.UID

    "Old Pod UID: $oldUid" |
        Tee-Object -FilePath $scenarioOutput -Append

    $oldUid | Set-Content (Join-Path $g6 "old-pod-uid.txt")

    "" | Tee-Object -FilePath $scenarioOutput -Append

    "=== Delete Pod ===" |
        Tee-Object -FilePath $scenarioOutput -Append

    k delete pod $targetPod -n $namespace --wait=true 2>&1 |
        Tee-Object -FilePath $scenarioOutput -Append

    if ($LASTEXITCODE -ne 0) {
        throw "Pod deletion failed."
    }

    "" | Tee-Object -FilePath $scenarioOutput -Append

    "=== Wait until new Pod object is created ===" |
        Tee-Object -FilePath $scenarioOutput -Append

    $deadline = (Get-Date).AddMinutes(3)

    do {
        Start-Sleep -Seconds 1

        $uidOutput = @(
            k get pod $targetPod `
                -n $namespace `
                -o jsonpath='{.metadata.uid}' `
                2>$null
        )

        if ($LASTEXITCODE -eq 0 -and $uidOutput.Count -gt 0) {
            $candidateUid = ($uidOutput -join "").Trim()

            if (
                -not [string]::IsNullOrWhiteSpace($candidateUid) -and
                $candidateUid -ne $oldUid
            ) {
                $newUid = $candidateUid
                break
            }
        }
    }
    while ((Get-Date) -lt $deadline)

    if ([string]::IsNullOrWhiteSpace($newUid)) {
        throw "A recreated Pod with a different UID was not observed within 3 minutes."
    }

    "New Pod UID: $newUid" |
        Tee-Object -FilePath $scenarioOutput -Append

    $newUid | Set-Content (Join-Path $g6 "new-pod-uid.txt")

    "" | Tee-Object -FilePath $scenarioOutput -Append

    "=== Wait until Pod is Ready again ===" |
        Tee-Object -FilePath $scenarioOutput -Append

    k wait `
        --for=condition=Ready `
        "pod/$targetPod" `
        -n $namespace `
        --timeout=300s `
        2>&1 |
        Tee-Object -FilePath $scenarioOutput -Append

    if ($LASTEXITCODE -ne 0) {
        throw "Recreated Pod did not become Ready within 300 seconds."
    }

    "" | Tee-Object -FilePath $scenarioOutput -Append

    "=== State after Pod recovery ===" |
        Tee-Object -FilePath $scenarioOutput -Append

    k get pod $targetPod -n $namespace -o wide 2>&1 |
        Tee-Object -FilePath $scenarioOutput -Append

    if ($LASTEXITCODE -ne 0) {
        throw "Could not record target Pod state after recovery."
    }

    "" | Tee-Object -FilePath $scenarioOutput -Append

    "=== Galera status after Pod recovery ===" |
        Tee-Object -FilePath $scenarioOutput -Append

    $postGaleraText = Invoke-GaleraStatus `
        -OutputFile (Join-Path $g6 "post-galera.txt") `
        -ScenarioOutputFile $scenarioOutput

    if (-not (Test-GaleraHealthy $postGaleraText)) {
        throw "Galera was not size=3 and Synced after recovery."
    }

    "" | Tee-Object -FilePath $scenarioOutput -Append

    "G6 Pod deletion and recovery completed successfully" |
        Tee-Object -FilePath $scenarioOutput -Append

    $scenarioSucceeded = $true
}
catch {
    $scenarioSucceeded = $false
    $scenarioExitCode = 1
    $scenarioError = $_.Exception.Message

    $scenarioError |
        Set-Content (Join-Path $g6 "scenario-error.txt")

    "" | Add-Content $scenarioOutput
    "G6 ERROR: $scenarioError" | Add-Content $scenarioOutput
}

"G6_EXIT_CODE=$scenarioExitCode" |
    Set-Content (Join-Path $g6 "exit-code.txt")


# ============================================================
# 4. END strict scenario window
# ============================================================

$endUtc = Get-ClusterUtc
$endUtc | Set-Content (Join-Path $g6 "end-utc.txt")

@"
G6_START_UTC=$startUtc
G6_END_UTC=$endUtc
"@ | Set-Content (Join-Path $g6 "scenario-window.txt")

Write-Host ""
Write-Host "G6 END:   $endUtc"
Write-Host ""


# ============================================================
# 5. Collect Tracee logs
# ============================================================

$collectionStartUtc = (
    (Convert-IsoToDateTimeOffset $startUtc).AddSeconds(-2)
).UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

$collectionStartUtc |
    Set-Content (Join-Path $g6 "collection-start-utc.txt")

Collect-TraceeLogs `
    -CollectionStartUtc $collectionStartUtc `
    -TraceePre $traceePre


# ============================================================
# 6. Save POST state
# ============================================================

k get pods -A -o wide |
    Out-File (Join-Path $g6 "post-all-pods.txt")

k get pods -n $namespace -o wide |
    Out-File (Join-Path $g6 "post-database-pods.txt")

k get pods -n $traceeNamespace -o wide |
    Out-File (Join-Path $g6 "post-tracee-pods.txt")

$targetPost = Get-TargetPodSnapshot -AllowMissing

if ($targetPost) {
    k get pod $targetPod -n $namespace -o yaml |
        Out-File (Join-Path $g6 "target-pod-post.yaml")

    $targetPost |
        Format-List |
        Out-String |
        Set-Content (Join-Path $g6 "target-pod-post.txt")
}
else {
    "Target Pod missing after G6." |
        Set-Content (Join-Path $g6 "target-pod-post.txt")
}

$traceePost = @(Get-TraceeAgents)

$traceePost |
    Sort-Object Node |
    Format-Table -AutoSize |
    Out-String |
    Set-Content (Join-Path $g6 "tracee-agents-post.txt")


# ============================================================
# 7. Validate recovery and Tracee stability
# ============================================================

$recoveryProblems = @()

if (-not $scenarioSucceeded) {
    $recoveryProblems += "The predefined G6 operation did not complete successfully."
}

if ([string]::IsNullOrWhiteSpace($oldUid)) {
    $recoveryProblems += "Old Pod UID was not recorded."
}

if ([string]::IsNullOrWhiteSpace($newUid)) {
    $recoveryProblems += "New Pod UID was not recorded."
}

if (
    -not [string]::IsNullOrWhiteSpace($oldUid) -and
    -not [string]::IsNullOrWhiteSpace($newUid) -and
    $oldUid -eq $newUid
) {
    $recoveryProblems += "Old and new Pod UIDs are identical."
}

if (-not $targetPost) {
    $recoveryProblems += "The recreated target Pod was not present after G6."
}
else {
    if ($targetPost.UID -eq $targetPre.UID) {
        $recoveryProblems += "The final target Pod still has the pre-deletion UID."
    }

    if ($newUid -and $targetPost.UID -ne $newUid) {
        $recoveryProblems += "The final Pod UID differs from the UID observed after recreation."
    }

    if ($targetPost.Phase -ne "Running" -or -not $targetPost.Ready) {
        $recoveryProblems += "The recreated Pod is not Running and Ready."
    }
}

if (-not (Test-GaleraHealthy $preGaleraText)) {
    $recoveryProblems += "Pre-deletion Galera status was not size=3 and Synced."
}

if (-not (Test-GaleraHealthy $postGaleraText)) {
    $recoveryProblems += "Post-recovery Galera status was not size=3 and Synced."
}

if ($recoveryProblems.Count -eq 0) {
    @"
G6 ground truth: OK
Old Pod UID: $oldUid
New Pod UID: $newUid
Pod UID changed: CONFIRMED
Recreated Pod Running and Ready: CONFIRMED
Pre-deletion Galera cluster size 3: CONFIRMED
Pre-deletion Galera local state Synced: CONFIRMED
Post-recovery Galera cluster size 3: CONFIRMED
Post-recovery Galera local state Synced: CONFIRMED
Pre-deletion node: $($targetPre.Node)
Post-recovery node: $($targetPost.Node)
"@ | Set-Content (Join-Path $g6 "scenario-validation.txt")
}
else {
    @(
        "G6 ground truth: CHECK REQUIRED"
        $recoveryProblems
    ) | Set-Content (Join-Path $g6 "scenario-validation.txt")
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
        $stabilityProblems += "No Tracee agent found on $node after G6."
        continue
    }

    if ($before.Pod -ne $after.Pod) {
        $stabilityProblems += "Tracee Pod changed on ${node}: $($before.Pod) -> $($after.Pod)"
    }

    if ($after.Restarts -ne $before.Restarts) {
        $stabilityProblems += "Tracee restart count changed on ${node}: $($before.Restarts) -> $($after.Restarts)"
    }

    if ($after.Phase -ne "Running") {
        $stabilityProblems += "Tracee agent on $node is not Running after G6."
    }
}

if ($stabilityProblems.Count -eq 0) {
    "Tracee agents stable during the run." |
        Set-Content (Join-Path $g6 "tracee-stability.txt")
}
else {
    $stabilityProblems |
        Set-Content (Join-Path $g6 "tracee-stability.txt")
}


# ============================================================
# 8. Strict START-END filtering
# ============================================================

$startNs = Convert-IsoToUnixNs $startUtc
$endNs   = Convert-IsoToUnixNs $endUtc

foreach ($node in $nodes) {
    Filter-TraceeWindow `
        -InputFile (Join-Path $g6 "$node-since-start.jsonl") `
        -OutputFile (Join-Path $g6 "$node-window.jsonl") `
        -StartNs $startNs `
        -EndNs $endNs
}


# ============================================================
# 9. Build detection overview
# ============================================================

$detections = @(Build-DetectionOverview)


# ============================================================
# 10. Run status
# ============================================================

$runStatus = @()

if ($scenarioSucceeded) {
    $runStatus += "G6 scenario: COMPLETE"
}
else {
    $runStatus += "G6 scenario: FAILED"
}

if ($recoveryProblems.Count -eq 0) {
    $runStatus += "G6 ground truth: OK"
}
else {
    $runStatus += "G6 ground truth: CHECK REQUIRED"
}

if ($stabilityProblems.Count -eq 0) {
    $runStatus += "Tracee stability: OK"
}
else {
    $runStatus += "Tracee stability: CHECK REQUIRED"
}

$runStatus += "START: $startUtc"
$runStatus += "END:   $endUtc"
$runStatus += "Old Pod UID: $oldUid"
$runStatus += "New Pod UID: $newUid"
$runStatus += "Pre-deletion node: $($targetPre.Node)"

if ($targetPost) {
    $runStatus += "Post-recovery node: $($targetPost.Node)"
}

$runStatus += "Tracee detections in strict window: $($detections.Count)"

$runStatus |
    Set-Content (Join-Path $g6 "run-status.txt")


# ============================================================
# Console summary
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host "G6 $Run finished"
Write-Host "============================================"
Write-Host "START: $startUtc"
Write-Host "END:   $endUtc"
Write-Host "Old Pod UID: $oldUid"
Write-Host "New Pod UID: $newUid"

if ($targetPost) {
    Write-Host "Node: $($targetPre.Node) -> $($targetPost.Node)"
}

Write-Host ""

if ($recoveryProblems.Count -eq 0) {
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
Write-Host $g6
Write-Host ""


# ============================================================
# Final validity checks
# ============================================================

if (-not $scenarioSucceeded) {
    throw "G6 scenario failed. See scenario-error.txt and scenario-output.txt."
}

if ($recoveryProblems.Count -gt 0) {
    throw "G6 ground-truth validation failed. See scenario-validation.txt."
}

if ($stabilityProblems.Count -gt 0) {
    throw "Tracee stability check failed. See tracee-stability.txt."
}

Write-Host "Run validity checks: OK"
