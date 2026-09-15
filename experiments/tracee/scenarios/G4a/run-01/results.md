Window: 13:03:20.351Z – 13:03:21.273Z

| Classification   | Detection                            |  Count |
| ---------------- | ------------------------------------ | -----: |
| Scenario-related | `falco-ref-terminal-shell-container` |  **1** |
| Unrelated        | `falco-ref-clear-log`                | **4** |

## Sceanrio-related attribution: 1

processName:   sh
processId:     387
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

## Unrelated 11

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
.../system.journal

master:   3
worker1:  1
worker2:  0
