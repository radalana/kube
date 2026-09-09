START  2026-09-09T13:29:23.741Z
END    2026-09-09T13:29:36.032Z
EXIT   0


read successfully 
/proc/1/cmdline
/proc/1/status
/proc/self/status
/proc/meminfo

# Inside window

| Policy                     | Raw records | Occurrences | Classification                      |
| -------------------------- | ----------: | ----------: | ----------------------------------- |
| `terminal-shell-container` |           1 |           1 | scenario-related                    | worker1 
| `private-key-search`       |           4 |           4 | unrelated                           | same as ambient on master 
| `sensitive-read-untrusted` |          20 |           1 | unrelated                           |again 20 raw sssh-session on master same  sshd session start 13:29:22.626Z so before window but continued inside the window
| **Total**                  |      **25** |       **6** | **1 scenario-related, 5 unrelated** |

Scenario-related = 1
Unrelated        = 5
Total            = 6
1. `terminal-shell-container` on worker 1:

13:29:28.351Z
falco-ref-terminal-shell-container
target = /usr/bin/sh


after 2 ms

/usr/bin/sh -c ...
Pod       = mariadb-galera-0
Namespace = database
Node      = worker1

Tetragon detected the shell used to execute the inspection, not the /proc reads themselves. -> limitation of policy i think


И pattern пока очень похож на G5a: inspection itself не даёт отдельного file/process-read detection; scenario-related match возникает из-за /usr/bin/sh