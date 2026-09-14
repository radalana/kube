START  2026-09-14T17:28:20.418Z
END    2026-09-14T17:28:24.137Z
≈ 3.72 s

| Classification   | Policy                               | Detections | Node                |
| ---------------- | ------------------------------------ | ---------: | ------------------- |
| Scenario-related | `falco-ref-terminal-shell-container` |      **1** | worker2             |
| Unrelated        | `falco-ref-clear-log`                |      **8** | master 1, worker2 7 |

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

# Unrelated 8

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
.../system.journal

master:   1
worker1:  0
worker2:  7



### outside window 

worker2-since-start.jsonl one more clear-log
