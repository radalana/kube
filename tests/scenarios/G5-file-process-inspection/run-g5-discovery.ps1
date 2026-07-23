# Stop script in case of error in Powershell
$ErrorActionPreference = "Stop"

Write-host "Starting G5 discovery"
Write-host "Target: namespace=database, pod=mariadb-galera-0, container=mariadb"
Write-host ""

Write-Host "=== Configuration file candidates under /etc ==="
# Command inside the container
# 2>/dev/null hide in case of error
k exec `
    -n database `
    mariadb-galera-0 `
    -c mariadb `
    -- sh -c 'find /etc -maxdepth 5 -type f \( -name "*.cnf" -o -name "*.conf" \) 2>/dev/null | sort'

Write-Host ""
Write-Host "=== Log file candidates under /var/log ==="
k exec `
    -n database `
    mariadb-galera-0 `
    -c mariadb `
    -- sh -c "find /var/log -maxdepth 5 -type f 2>/dev/null | sort"

Write-Host ""
#in /proc directory contains information about prcesses, which command launce the process, memory and files availeble to the process
Write-Host "=== Selected /proc files ==="
k exec `
    -n database `
    mariadb-galera-0 `
    -c mariadb `
    -- sh -c 'ls -l /proc/1/status /proc/1/cmdline /proc/self/status /proc/meminfo 2>/dev/null'

#error of kubectl
if ($LASTEXITCODE -ne 0) {
    throw "G5 discovery failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "G5 discovery completed successfulley"

