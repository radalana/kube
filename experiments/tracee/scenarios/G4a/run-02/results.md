Window: 15:23:31.272Z – 15:23:32.240Z


| Classification   | Detection                            | Count |
| ---------------- | ------------------------------------ |-----: |
| Scenario-related | `falco-ref-terminal-shell-container` | **1** |
| Unrelated        | `falco-ref-clear-log`                | **5** |


## Sceanrio-related attribution: 1

processName:   sh
processId:     397
cmdpath:       /usr/bin/sh
pathname:      /usr/bin/dash
stdin_path:    /dev/null
eventName:     sched_process_exec
policy:        falco-ref-terminal-shell-container
node:          worker1

argv contains G4a workload: sh -c "id; hostname; ps"

shell is non-interactive,
TTY=? in scenario ps output,
stdin_path=/dev/null

## Unrelated 5

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
.../system.journal

master:   3
worker1:  1
worker2:  1
