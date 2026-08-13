# ============================================================
# Common evidence collection functions for Tetragon experiments
# ============================================================


function Protect-EvidenceText {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Lines
    )

    $Lines | ForEach-Object {

        $line = $_

        # Redact passwords passed as command-line arguments.
        $line = $line -replace `
            '(--password=)([^ \\"''\r\n]+)', `
            '$1<REDACTED>'

        $line
    }
}


function Save-TetragonState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    kubectl get pods `
        -n kube-system `
        -l app.kubernetes.io/name=tetragon `
        -o custom-columns='POD:.metadata.name,UID:.metadata.uid,NODE:.spec.nodeName,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount' |
        Out-File $Path -Encoding utf8
}


function Save-DatabaseState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EvidenceDir,

        [Parameter(Mandatory = $true)]
        [ValidateSet("before", "after")]
        [string]$Phase
    )

    kubectl get pods `
        -n database `
        -o wide |
        Out-File `
            "$EvidenceDir\database-pods-$Phase.txt" `
            -Encoding utf8


    kubectl get jobs `
        -n database `
        -o wide |
        Out-File `
            "$EvidenceDir\jobs-$Phase.txt" `
            -Encoding utf8
}


function Save-PodEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Namespace,

        [Parameter(Mandatory = $true)]
        [string]$PodName,

        [Parameter(Mandatory = $true)]
        [string]$EvidenceDir
    )

    $podJson = kubectl get pod `
        $PodName `
        -n $Namespace `
        -o json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get Pod $Namespace/$PodName"
    }


    $podJson |
        Out-File `
            "$EvidenceDir\scenario-target-pod.json" `
            -Encoding utf8


    $pod = $podJson | ConvertFrom-Json


    $summary = foreach (
        $container in $pod.status.containerStatuses
    ) {

        [PSCustomObject]@{
            PodName       = $pod.metadata.name
            PodUID        = $pod.metadata.uid
            PodIP         = $pod.status.podIP
            Node          = $pod.spec.nodeName
            ContainerName = $container.name
            ContainerID   = $container.containerID
            Image         = $container.image
            Ready         = $container.ready
            RestartCount  = $container.restartCount
        }
    }


    $summary |
        Format-List |
        Out-String -Width 4096 |
        Out-File `
            "$EvidenceDir\scenario-target-pod-summary.txt" `
            -Encoding utf8
}


function Save-JobEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Namespace,

        [Parameter(Mandatory = $true)]
        [string]$JobName,

        [Parameter(Mandatory = $true)]
        [string]$EvidenceDir
    )

    kubectl get job `
        $JobName `
        -n $Namespace `
        -o yaml |
        Out-File `
            "$EvidenceDir\scenario-job.yaml" `
            -Encoding utf8
}


function Save-ScenarioPodLogs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Namespace,

        [Parameter(Mandatory = $true)]
        [string]$PodName,

        [Parameter(Mandatory = $true)]
        [string]$EvidenceDir
    )

    $logs = @(
        kubectl logs `
            -n $Namespace `
            $PodName `
            --all-containers=true
    )

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "Failed to collect logs from $Namespace/$PodName"
    }


    $logs |
        Protect-EvidenceText |
        Out-File `
            "$EvidenceDir\scenario-pod-logs.txt" `
            -Encoding utf8
}


function Save-TetragonEvents {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartTime,

        [Parameter(Mandatory = $true)]
        [string]$EndTime,

        [Parameter(Mandatory = $true)]
        [string]$EvidenceDir
    )


    $allPath =
        "$EvidenceDir\all-tetragon-events.txt"

    $windowPath =
        "$EvidenceDir\tetragon-events-window.txt"

    $policyPath =
        "$EvidenceDir\policy-events.txt"

    $countPath =
        "$EvidenceDir\policy-event-count.txt"

    $statusPath =
        "$EvidenceDir\log-collection-status.txt"


    # --------------------------------------------------------
    # Collect all available Tetragon records since start time.
    # --------------------------------------------------------

    $rawEvents = @(
        kubectl logs `
            -n kube-system `
            -l app.kubernetes.io/name=tetragon `
            -c export-stdout `
            --since-time=$StartTime `
            --timestamps `
            --prefix `
            --tail=-1
    )

    $logExitCode = $LASTEXITCODE


    # Redact authentication values before storing evidence.
    $rawEvents = @(
        $rawEvents |
            Protect-EvidenceText
    )


    # Always create the file, including when no events exist.
    New-Item `
        -ItemType File `
        -Force `
        -Path $allPath |
        Out-Null


    if ($rawEvents.Count -gt 0) {
        $rawEvents |
            Set-Content `
                $allPath `
                -Encoding utf8
    }


    "kubectl logs exit code: $logExitCode" |
        Out-File `
            $statusPath `
            -Encoding utf8


    # --------------------------------------------------------
    # Restrict records to the actual scenario time window.
    # --------------------------------------------------------

    $start =
        [DateTimeOffset]::Parse($StartTime)

    $end =
        [DateTimeOffset]::Parse($EndTime)


    $eventsInWindow = @(
        foreach ($line in $rawEvents) {

            $jsonStart =
                $line.IndexOf("{")


            if ($jsonStart -lt 0) {
                continue
            }


            try {

                $jsonText =
                    $line.Substring($jsonStart)

                $event =
                    $jsonText |
                    ConvertFrom-Json `
                        -ErrorAction Stop


                if (-not $event.time) {
                    continue
                }


                $eventTime =
                    [DateTimeOffset]::Parse(
                        $event.time
                    )


                if (
                    ($eventTime -ge $start) -and
                    ($eventTime -le $end)
                ) {
                    $line
                }
            }
            catch {
                # Ignore non-JSON or malformed log records.
            }
        }
    )


    New-Item `
        -ItemType File `
        -Force `
        -Path $windowPath |
        Out-Null


    if ($eventsInWindow.Count -gt 0) {
        $eventsInWindow |
            Set-Content `
                $windowPath `
                -Encoding utf8
    }


    # --------------------------------------------------------
    # Extract policy-generated detections.
    # --------------------------------------------------------

    $policyEvents = @(
        $eventsInWindow |
            Where-Object {

                $_ -match '"process_kprobe"' -and
                $_ -match '"policy_name":"file-monitoring-filtered"'
            }
    )


    New-Item `
        -ItemType File `
        -Force `
        -Path $policyPath |
        Out-Null


    if ($policyEvents.Count -gt 0) {
        $policyEvents |
            Set-Content `
                $policyPath `
                -Encoding utf8
    }


    # --------------------------------------------------------
    # Count raw records and unique process executions.
    # --------------------------------------------------------

    $execIds = @(
        foreach ($line in $policyEvents) {

            $jsonStart =
                $line.IndexOf("{")


            if ($jsonStart -lt 0) {
                continue
            }


            try {

                $event =
                    $line.Substring($jsonStart) |
                    ConvertFrom-Json `
                        -ErrorAction Stop


                $execId =
                    $event.process_kprobe.process.exec_id


                if ($execId) {
                    $execId
                }
            }
            catch {
            }
        }
    )


    $uniqueExecIds =
        @(
            $execIds |
                Sort-Object -Unique
        )


    @(
        "Raw policy event records: $($policyEvents.Count)"
        "Unique process exec_id values: $($uniqueExecIds.Count)"
        ""
        "Note: unique exec_id count is supporting information."
        "Multiple raw process_kprobe records may belong to one underlying operation."
        "Final detection grouping is performed during event analysis using exec_id and event context."
    ) |
        Out-File `
            $countPath `
            -Encoding utf8
}

#