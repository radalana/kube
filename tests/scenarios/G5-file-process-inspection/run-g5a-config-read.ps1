# Reads selected MariaDB configuration files inside the container.
# Sensitive configuration lines are redacted before they are written to evidence.

$ErrorActionPreference = "Stop"

Write-Host "Starting G5a: authorized MariaDB configuration file inspection"
Write-Host "Target: namespace=database, pod=mariadb-galera-0, container=mariadb"
Write-Host ""

k exec `
    -n database `
    mariadb-galera-0 `
    -c mariadb `
    -- sh -c 'set -eu; echo "=== Hostname ==="; hostname; echo ""; echo "=== Selected MariaDB configuration files ==="; for f in /etc/mysql/mariadb.cnf /etc/mysql/mariadb.conf.d/0-galera.cnf; do echo ""; echo "--- $f ---"; ls -l "$f"; echo ""; while IFS= read -r line; do case "$line" in wsrep_sst_auth=*) echo "wsrep_sst_auth=<redacted>";; *password*|*Password*|*PASSWORD*|*secret*|*Secret*|*SECRET*) echo "<redacted sensitive line>";; *) echo "$line";; esac; done < "$f"; done'

if ($LASTEXITCODE -ne 0) {
    throw "G5a config read failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "G5a config read completed successfully"