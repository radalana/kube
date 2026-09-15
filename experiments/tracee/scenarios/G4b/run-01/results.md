START: 15:36:59.341Z
END:   15:37:16.767Z

| Classification   | Detection                            |  Count |
| ---------------- | ------------------------------------ | -----: |
| Scenario-related | `falco-ref-terminal-shell-container` |  **1** |
| Unrelated        | `falco-ref-clear-log`                | **15** |

## Sceanrio-related attribution: 1
processName:   sh
processId:     416
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

## Unrelated 15

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
.../system.journal

master:   6
worker1:  6
worker2:  3
