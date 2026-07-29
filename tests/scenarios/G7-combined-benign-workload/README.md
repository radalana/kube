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


### G7 re-validation

The initial version of G7 included the Galera pre-check and cleanup of previous
G1-G3 Jobs in the scenario script. Before the runtime security experiment,
these preparation steps were moved outside the scenario execution window to
avoid including cleanup activity in the collected runtime events.

The combined workload itself was not changed. The modified script was executed
again successfully to verify that G1-G6 still completed as expected.