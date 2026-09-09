START  2026-09-09T 14:24: 30.286Z
END    2026-09-09T 14:24: 38.786Z
EXIT   0

| Node    | First event   | Last event    |
| ------- | ------------- | ------------- |
| master  | 14:23:57.079Z | 14:24:41.157Z |
| worker1 | 14:24:19.218Z | 14:24:41.467Z |
| worker2 | 14:24:24.296Z | 14:24:41.777Z |


in window
| Policy                     | Raw records | Occurrences | Classification             |
| -------------------------- | ----------: | ----------: | -------------------------- |
| `terminal-shell-container` |           1 |       **1** | scenario-related           | worker1
| `private-key-search`       |           2 |       **2** | unrelated                  | master inside window apiservie keicjer 
| `sensitive-read-untrusted` |           0 |           0 | —                          |
| **Total**                  |       **3** |       **3** | **1 related, 2 unrelated** |


## terminal shell

14:24:34.726432Z
falco-ref-terminal-shell-container
target = /usr/bin/sh

in 2 ms

14:24:34.728446Z
/usr/bin/sh -c ...
Pod       = mariadb-galera-0
Namespace = database
Node      = worker1