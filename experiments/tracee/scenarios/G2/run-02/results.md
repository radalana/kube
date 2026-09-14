START  2026-09-14T17:24:47.750Z
END    2026-09-14T17:24:51.590Z
≈ 3.84 s

| Classification   | Policy                               | Detections | Node                           |
| ---------------- | ------------------------------------ | ---------: | ------------------------------ |
| Scenario-related | `falco-ref-terminal-shell-container` |      **1** | worker2                        |
| Unrelated        | `falco-ref-clear-log`                |     **11** | master 1, worker1 1, worker2 9 |

# Sceanrio-related attribution: 1

processName:   sh
processId:     1
cmdpath:       /usr/bin/sh
pathname:      /usr/bin/dash
stdin_path:    /dev/null
eventName:     sched_process_exec
policy:        falco-ref-terminal-shell-container
node:          worker2

argv contains G2 workload 
shell is main process processid 1 and not interactive stdin_path=/dev/null

# Unrelated 11

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
.../system.journal

master:   1
worker1:  1
worker2:  9