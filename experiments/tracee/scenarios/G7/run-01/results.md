Window: 17:36:23.256Z–17:37:03.783Z

| Classification             | Detection                            |  Count |
| -------------------------- | ------------------------------------ | -----: |
| Scenario-related           | `falco-ref-terminal-shell-container` | **12** |
| Scenario-related           | `falco-ref-k8s-api-contact`          |  **2** |
| **Scenario-related total** |                                      | **14** |
| Unrelated                  | `falco-ref-clear-log`                | **62** |
| **Total**                  |                                      | **76** |

falco-ref-terminal-shell-container distribution over scenarios: 
G1 CRUD                         1
G2 schema migration             1
G3 backup                       1
G4a non-interactive exec        1
G5a config inspection           0
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
TOTAL                          12

## k8s-api-contact -> galera init agent
## clear log
master   25
worker1  19
worker2  18
TOTAL    62



inner Errors messages on worker1: 

error reading argument from buffer for sched_process_exit

