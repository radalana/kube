START: 2026-09-15T17:13:14.975Z
END:   2026-09-15T17:13:31.640Z

| Classification   | Detection                            |  Count |
| ---------------- | ------------------------------------ | -----: |
| Scenario-related | `falco-ref-terminal-shell-container` |  **1** |
| Unrelated        | `falco-ref-clear-log`                | **15** |

## Sceanrio-related attribution: 1
processName:   sh
processId:     451
cmdpath:       /usr/bin/sh
pathname:      /usr/bin/dash
stdin_path:    /dev/pts/0
eventName:     sched_process_exec
policy:        falco-ref-terminal-shell-container
node:          worker1
argv:          sh


interactive shell,
TTY=pts/0 in scenario ps output,
stdin_path=/dev/pts/0

## Unrelated 13

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
.../system.journal

master:   7
worker1:  5
worker2:  3
