START: 2026-09-15T21:00:58.157Z
END:   2026-09-15T21:00:59.106Z

| Classification   | Detection                            | Count |
| ---------------- | ------------------------------------ | ----: |
| Scenario-related | `falco-ref-terminal-shell-container` | **1** |
| Unrelated        | `falco-ref-clear-log`                | **5** |

## Scenario-related attribution: 1

processName:   sh
processId:     520
cmdpath:       /usr/bin/sh
pathname:      /usr/bin/dash
stdin_path:    /dev/null
eventName:     sched_process_exec

policy:        falco-ref-terminal-shell-container
node:          worker1
argv:          sh -c <G5c predefined /proc inspection command>


non-interactive shell,
stdin_path=/dev/null,

argv contains inspection of:
/proc/1/cmdline
/proc/1/status
/proc/self/status
/proc/meminfo

No separate falco-ref-* detection was produced for the direct reads of the selected /proc files.

## Unrelated: 5

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
journal files

master:   4
worker1:  1
worker2:  0