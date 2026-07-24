# Deletes one MariaDB Galera Pod and waits until it is recreated and ready again.

$ErrorActionPreference = "Stop"

$namespace = "database"
$pod = "mariadb-galera-0"
$container = "mariadb"

Write-Host "=== State before Pod deletion ==="
k get pod -n $namespace $pod -o wide

Write-Host ""
Write-Host "=== Galera status before Pod deletion ==="
$sql = @"
SHOW STATUS LIKE 'wsrep_cluster_size';
SHOW STATUS LIKE 'wsrep_local_state_comment';
"@

$sql | k exec -i `
    -n database `
    mariadb-galera-0 `
    -c mariadb `
    -- sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"'


if ($LASTEXITCODE -ne 0) {
    throw "G6 pre-check failed with exit code $LASTEXITCODE"
}

$oldUid = k get pod mariadb-galera-0 -n database -o jsonpath='{.metadata.uid}'
Write-Host "Old Pod UID: $oldUid"

Write-Host ""
Write-Host "=== Delete Pod ==="

k delete pod mariadb-galera-0 -n $namespace --wait=false

if ($LASTEXITCODE -ne 0) {
    throw "Pod deletion failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "=== Wait until new Pod object is created ==="

$newUid = ""

for ($i = 1; $i -le 60; $i++) {
    Start-Sleep -Seconds 5

    $newUid = k get pod mariadb-galera-0 -n database -o jsonpath='{.metadata.uid}' 2>$null

    if ($newUid -and $newUid -ne $oldUid) {
        Write-Host "New Pod UID: $newUid"
        break
    }

    Write-Host "Waiting for new Pod UID..."
}

if (-not $newUid -or $newUid -eq $oldUid) {
    throw "Pod was not recreated. UID did not change."
}



Write-Host ""
Write-Host "=== Wait until Pod is Ready again ==="
k wait --for=condition=Ready pod/$pod -n $namespace --timeout=300s

if ($LASTEXITCODE -ne 0) {
    throw "G6 recovery wait failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "=== State after Pod recovery ==="
k get pod -n $namespace $pod -o wide

Write-Host ""
Write-Host "=== Galera status after Pod recovery ==="
$sql = @"
SHOW STATUS LIKE 'wsrep_cluster_size';
SHOW STATUS LIKE 'wsrep_local_state_comment';
"@

$sql | k exec -i `
    -n database `
    mariadb-galera-0 `
    -c mariadb `
    -- sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"'

if ($LASTEXITCODE -ne 0) {
    throw "G6 post-check failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "G6 Pod deletion and recovery completed successfully"