$ErrorActionPreference = "Stop"

Write-Host "Starting G4a: authorized non-interactive kubectl exec"

k exec `
  -n database `
  mariadb-galera-0 `
  -c mariadb `
  -- sh -c 'id; hostname; ps'

if ($LASTEXITCODE -ne 0) {
    throw "G4a failed with exit code $LASTEXITCODE"
}

Write-Host "G4a completed successfully"