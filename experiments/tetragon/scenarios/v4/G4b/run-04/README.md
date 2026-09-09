2026-09-09T09:05:52.925Z
–
2026-09-09T09:06:33.832Z


on worker1:
09:06:06.750290  falco-ref-terminal-shell-container
                  target = /usr/bin/sh

09:06:06.752908  /usr/bin/sh
                  mariadb-galera-0 / mariadb

09:06:11.179260  /usr/bin/id
09:06:14.690713  /usr/bin/hostname
09:06:18.522004  /usr/bin/ps

09:06:24.832825  shell exits

there is a runc --console-socket .../pty2506026414/pty.sock -> so actually tetragon sees pty

| Policy                     | Raw records | Occurrences | Attribution                          |
| -------------------------- | ----------: | ----------: | ------------------------------------ |
| `terminal-shell-container` |           1 |       **1** | **scenario-related**                 |
| `private-key-search`       |          16 |      **16** | unrelated              (from ambient)          |
| **Total**                  |      **17** |      **17** | **1 scenario-related, 16 unrelated** |
