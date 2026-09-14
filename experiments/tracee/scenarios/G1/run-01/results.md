START  2026-09-13T20:43:41.157Z
END    2026-09-13T20:43:44.918Z
≈ 3.76 s
| Classification   | Policy                               | Detections |
| ---------------- | ------------------------------------ | ---------: |
| Scenario-related | `falco-ref-terminal-shell-container` |      **1** |
| Unrelated        | `falco-ref-clear-log`                |      **2** |


# Related 1
G1 Pod was on worker 2

in worker2 1 deteciton found: 1 scenario-related benign detection: falco-ref-terminal-shell-container.

20:43:41.263Z
eventName:       sched_process_exec
policy:          falco-ref-terminal-shell-container
hostName:        g1-crud-8mjfg
processName:     sh
pathname:        /usr/bin/dash
stdin_path:      /dev/null

AND argv contains all G1 Crud commands: mariadb launch, sql....

# Unrelated 2

| Node      | Process           | Target                      | Raw detections |
| --------- | ----------------- | --------------------------- | -------------: |
| master    | `systemd-journal` | node-local `system.journal` |              1 |
| worker2   | `systemd-journal` | node-local `system.journal` |              8 |
| **Total** |                   |                             |          **9** |


eventName: do_truncate
policy: falco-ref-clear-log
processName: systemd-journal
pathname: /var/log/journal/.../system.journal           --> FROM AMBIENT
syscall: ftruncate

## EXTRA (not detections)
on worker2: 
```
error enriching container in control plane
unsupported runtime containerd 

Это не detections, у них нет matchedPolicies, поэтому в counts они не входят. При этом scenario event всё равно содержит containerId, hostName,
