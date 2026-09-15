START: 2026-09-15T20:11:50.360Z
END: 2026-09-15T20:11:51.294Z

| Classification   | Detection                            | Count |
| ---------------- | ------------------------------------ | ----: |
| Scenario-related | `falco-ref-terminal-shell-container` | **1** |
| Unrelated        | `falco-ref-clear-log`                | **5** |

## Scenario-related attribution: 1

processName:   sh
processId:     489
cmdpath:       /usr/bin/sh
pathname:      /usr/bin/dash
stdin_path:    /dev/null
eventName:     sched_process_exec
policy:        falco-ref-terminal-shell-container
node:          worker1
argv:          sh -c <G5a predefined configuration inspection command>


non-interactive shell,
stdin_path=/dev/null,

argv contains inspection of:
/etc/mysql/mariadb.cnf
/etc/mysql/mariadb.conf.d/0-galera.cnf

No separate falco-ref-* detection was produced for the direct reads of the two configuration files.

## Unrelated: 5

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
journal files

master:   4
worker1:  1
worker2:  0