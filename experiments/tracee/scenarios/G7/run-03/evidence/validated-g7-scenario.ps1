# Runs a combined workload using already validated G1-G6 scenarios.

$ErrorActionPreference = "Stop"

$namespace = "database"

$g1Manifest = ".\tests\scenarios\G1-crud\g1-crud.yaml"
$g2Manifest = ".\tests\scenarios\G2-schema-migration\g2-schema-migration.yaml"
$g3Manifest = ".\tests\scenarios\G3-backup\g3-backup.yaml"

$g4aScript = ".\tests\scenarios\G4-kubectl-exec\run-g4a-non-interactive.ps1"
$g5aScript = ".\tests\scenarios\G5-file-process-inspection\run-g5a-config-read.ps1"
$g5cScript = ".\tests\scenarios\G5-file-process-inspection\run-g5c-proc-read.ps1"
$g6Script = ".\tests\scenarios\G6-pod-delete-recovery\run-g6-pod-delete-recovery.ps1"

$sql = @"
SHOW STATUS LIKE 'wsrep_cluster_size';
SHOW STATUS LIKE 'wsrep_local_state_comment';
"@

Write-Host "Starting G7: combined benign workload"
Write-Host "Namespace: $namespace"
Write-Host ""

Write-Host "=== Phase 1: Start G1, G2, and G3 Jobs ==="

k apply -f $g1Manifest
if ($LASTEXITCODE -ne 0) { throw "G7 failed to apply G1" }

k apply -f $g2Manifest
if ($LASTEXITCODE -ne 0) { throw "G7 failed to apply G2" }

k apply -f $g3Manifest
if ($LASTEXITCODE -ne 0) { throw "G7 failed to apply G3" }

Write-Host ""
Write-Host "=== Phase 2: Run G4a non-interactive kubectl exec ==="

& $g4aScript

if ($LASTEXITCODE -ne 0) {
    throw "G7 G4a phase failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "=== Phase 3: Run G5 file and process inspection ==="

& $g5aScript

if ($LASTEXITCODE -ne 0) {
    throw "G7 G5a phase failed with exit code $LASTEXITCODE"
}

& $g5cScript

if ($LASTEXITCODE -ne 0) {
    throw "G7 G5c phase failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "=== Phase 4: Wait for G1-G3 Jobs to complete ==="

k wait --for=condition=complete job/g1-crud -n $namespace --timeout=180s
if ($LASTEXITCODE -ne 0) { throw "G7 G1 job did not complete" }

k wait --for=condition=complete job/g2-schema-migration -n $namespace --timeout=180s
if ($LASTEXITCODE -ne 0) { throw "G7 G2 job did not complete" }

k wait --for=condition=complete job/g3-backup -n $namespace --timeout=180s
if ($LASTEXITCODE -ne 0) { throw "G7 G3 job did not complete" }

Write-Host ""
Write-Host "=== G1-G3 Job status ==="

k get job -n $namespace g1-crud g2-schema-migration g3-backup

Write-Host ""
Write-Host "=== Phase 5: Run G6 Pod deletion and recovery ==="

& $g6Script

if ($LASTEXITCODE -ne 0) {
    throw "G7 G6 phase failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "=== Final Galera status after combined workload ==="

$sql | k exec -i `
    -n $namespace `
    mariadb-galera-0 `
    -c mariadb `
    -- sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"'

if ($LASTEXITCODE -ne 0) {
    throw "G7 final Galera check failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "G7 combined benign workload completed successfully"