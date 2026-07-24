# G7: Combined benign workload

## Purpose

G7 represents a combined benign workload in the Kubernetes-based MariaDB Galera
environment. The scenario combines already validated benign operations in one
shared workload window.

The purpose is to check whether several legitimate actions close together can
produce security-relevant runtime activity, such as database access, process
execution, file inspection, and Pod lifecycle events.

## Implementation

The scenario starts the G1, G2, and G3 Kubernetes Jobs close together. These Jobs
are submitted sequentially by the script, but Kubernetes can execute them
asynchronously within the same workload window.

After submitting the Jobs, the script runs G4a non-interactive `kubectl exec`
and G5 file/process inspection. Then it waits until the G1-G3 Jobs complete.
Finally, the script runs G6 Pod deletion and recovery.

G6 is executed at the end because it deletes `mariadb-galera-0`, which is also
used by G4 and G5.

## Run command

```powershell
.\tests\scenarios\G7-combined-benign-workload\run-g7-combined-benign-workload.ps1 *> .\tests\scenarios\G7-combined-benign-workload\evidence\g7-combined-run-1.txt