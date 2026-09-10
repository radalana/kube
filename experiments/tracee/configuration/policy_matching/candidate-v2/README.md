| Приоритет | Policy                               | Почему проверить                          |
| --------- | ------------------------------------ | ----------------------------------------- |
| 1         | `falco-ref-directory-traversal-read` | wildcard + `data.pathname`                |
| 2         | `falco-ref-sensitive-read-trusted`   | pathname + `comm`                         |
| 3         | `falco-ref-sensitive-read-untrusted` | большое количество `comm!=...`            |
| 4         | `falco-ref-terminal-shell-container` | container + shell filtering               |
| 5         | `falco-ref-netcat-rce`               | container + `comm=nc,ncat`                |
| 6         | `falco-ref-clear-log`                | наш переход на `do_truncate`              |
| 7         | `falco-ref-symlink-sensitive`        | `data.target`                             |
| 8         | `falco-ref-hardlink-sensitive`       | `data.oldpath`                            |
| 9         | `falco-ref-packet-socket`            | особенно важно проверить `data.domain=17` |
| 10        | `falco-ref-debugfs-privileged`       | custom approximation                      |
| 11        | `falco-ref-ptrace-attach`            | наши конкретные `data.request` values     |
| 12        | `falco-ref-exec-dev-shm`             | `security_bprm_check` + pathname          |
