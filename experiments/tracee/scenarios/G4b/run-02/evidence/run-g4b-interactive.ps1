$ErrorActionPreference = "Stop"


Write-Host "Starting G4b: authorized interactive shell"
Write-Host "Inside the container, run:"
Write-Host "  id"
Write-Host "  hostname"
Write-Host "  ps"
Write-Host "  exit"

k exec `
  -it `
  -n database `
  mariadb-galera-0 `
  -c mariadb `
  -- sh

if ($LASTEXITCODE -ne 0) {
    throw "G4b failed with exit code $LASTEXITCODE"
}

Write-Host "G4b completed successfully"