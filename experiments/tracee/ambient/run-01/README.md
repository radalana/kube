planned start: 2026-09-10T20:41:21.339Z
planned end:   2026-09-10T21:11:21.339Z
SSH loss:      ~2026-09-10T21:15:58Z

falco-ref-clear-log: 238 events:

master: 138
worker1: 64
worker2: 36


process: systemd-journal
event: do_truncate
syscall ftruncate
arget: node-local /var/log/journal/.../system.journal