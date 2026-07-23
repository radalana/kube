# Reads selected /proc files inside the MariaDB container.

$ErrorActionPreference = "Stop"

Write-Host "Starting G5c: authorized /proc process inspection"
Write-Host "Target: namespace=database, pod=mariadb-galera-0, container=mariadb"
Write-Host ""

k exec `
    -n database `
    mariadb-galera-0 `
    -c mariadb `
    -- sh -c 'set -eu; echo "=== Hostname ==="; hostname; echo ""; echo "=== /proc/1/cmdline ==="; cat /proc/1/cmdline; echo ""; echo ""; echo "=== /proc/1/status ==="; cat /proc/1/status; echo ""; echo "=== /proc/self/status ==="; cat /proc/self/status; echo ""; echo "=== /proc/meminfo ==="; cat /proc/meminfo'

if ($LASTEXITCODE -ne 0) {
    throw "G5c proc read failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "G5c proc read completed successfully"