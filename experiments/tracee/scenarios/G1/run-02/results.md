START  2026-09-14T12:03:23.666Z
END    2026-09-14T12:03:27.275Z
≈ 3.61 s

| Classification   | Policy                               | Detections |
| ---------------- | ------------------------------------ | ---------: |
| Scenario-related | `falco-ref-terminal-shell-container` |      **1** |
| Unrelated        | `falco-ref-clear-log`                |      **6** |

# Related 1
G1 Pod was on worker 2

in worker2 1 deteciton found: 1 scenario-related benign detection: falco-ref-terminal-shell-container.

eventName:       sched_process_exec
policy:          falco-ref-terminal-shell-container
hostName:        g1-crud-8mjfg
processName:     sh
pathname:        /usr/bin/dash
stdin_path:      /dev/null



# Unrelated 6

| Node      | Process           | Target                      | Raw detections |
| --------- | ----------------- | --------------------------- | -------------: |
| worker2   | `systemd-journal` | node-local `system.journal` |              6 |
| **Total** |                   |                             |          **6** |

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
/var/log/journal/.../system.journal
