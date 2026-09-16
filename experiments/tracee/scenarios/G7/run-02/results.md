17:44:57.566Z–17:45:38.795Z

| Classification             | Detection                            |  Count |
| -------------------------- | ------------------------------------ | -----: |
| Scenario-related           | `falco-ref-terminal-shell-container` | **13** |
| Scenario-related           | `falco-ref-k8s-api-contact`          |  **2** |
| **Scenario-related total** |                                      | **15** |
| Unrelated                  | `falco-ref-clear-log`                | **72** |
| **Total**                  |                                      | **87** |


## shell detections:
G1 CRUD                         1
G2 schema migration             1
G3 backup                       1
G4a non-interactive exec        1
G5a config inspection           1
G5c /proc inspection            1

G6:
  pre-recovery Galera check     1
  SST donor sh + bash           2
  SST joiner sh + bash          2
  post-recovery Galera check    1
                                ─
                                6

G7 final Galera check           1
                                ─
TOTAL                          13

k8s-api-contact:

G6 recovery

clear-log:
master   35
worker1  22
worker2  15
TOTAL    72