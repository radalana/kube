# Kubernetes Runtime Security Experiments

This repository contains the experimental setup and evidence used for a
Bachelor's thesis evaluating benign security-relevant operations in a
Kubernetes-based MariaDB Galera environment with the runtime security tools
Falco, Tetragon, and Tracee.

## Repository Structure

```text
cluster/
tests/
experiments/
```

### `cluster/`

Kubernetes and MariaDB Galera configuration used to build the test
environment, including namespaces, storage, monitoring, the MariaDB operator,
cluster configuration, users, grants, and secrets.

### `tests/scenarios/`

Implementation and validation material for the predefined benign scenarios:

```text
G1-crud/
G2-schema-migration/
G3-backup/
G4-kubectl-exec/
G5-file-process-inspection/
G6-pod-delete-recovery/
G7-combined-benign-workload/
```

Each scenario directory contains the scenario manifest or script and the
validation output in `evidence/`. All
scenarios were validated independently before being executed with the runtime
security tools.

### `experiments/`

Experimental material for the three evaluated tools:

```text
experiments/
├── falco/
├── tetragon/
└── tracee/
```

Each tool directory holds the deployment and installation snapshots, the
detection configurations and the material from the mapping to the Falco
reference rules, the ambient observations, and the scenario runs with their
evidence. The directory layout differs between the tools.

Some directories also retain preliminary configurations, policy candidates,
validation tests, and excluded runs. These document the development of the
final setup and are not part of the reported results.

## Scenario Runs

A run directory typically contains the tool output or raw event streams, the
scenario output, the recorded start and end timestamps, the cluster and
workload state before and after execution, and the tool status including
restart counts.

For Tetragon, the files `master.json`, `worker1.json`, and `worker2.json`
contain the complete event streams collected from the agent on the respective
node. They are raw event streams, not pre-filtered lists of detections. The
policy matches were extracted and correlated with process, workload,
timestamp, node, and scenario context during the analysis.

