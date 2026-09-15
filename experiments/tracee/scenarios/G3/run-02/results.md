Window:   11:01:23.592Z – 11:01: 28.598Z
Job live: 11:01:23Z     – 11:01: 27Z

| Classification   | Detection                            |  Count |
| ---------------- | ------------------------------------ | -----: |
| Scenario-related | `falco-ref-terminal-shell-container` |  **1** |
| Unrelated        | `falco-ref-clear-log`                | **10** |

## Sceanrio-related attribution: 1

processName:   sh
processId:     1
cmdpath:       /usr/bin/sh
pathname:      /usr/bin/dash
stdin_path:    /dev/null
eventName:     sched_process_exec
policy:        falco-ref-terminal-shell-container
node:          worker2


argv contains G3 logical-backup workload

shell is main process, processId 1, and not interactive,
stdin_path=/dev/null

## Unrelated 11

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
.../system.journal

master:   2
worker1:  0
worker2:  8
