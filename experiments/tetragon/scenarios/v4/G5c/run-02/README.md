START  2026-09-09T 13:35: 17.531Z
END    2026-09-09T 13:35: 25.595Z
EXIT   0

| Node    | First event   | Last event    |
| ------- | ------------- | ------------- |
| master  | 13:35: 01.093Z | 13:35: 28.892Z |
| worker1 | 13:35: 06.947Z | 13:35: 29.217Z |
| worker2 | 13:35: 10.943Z | 13:35: 29.534Z |


# Terminal shell container -> related
13:35:21.943920959Z -> inside window
falco-ref-terminal-shell-container
function = __x64_sys_execve
target   = /usr/bin/sh
node     = worker1

after 2ms 

13:35:21.946007065Z -> inside
/usr/bin/sh -c ...
Pod       = mariadb-galera-0
Namespace = database
Container = mariadb
Node      = worker1

shell arguments:
cat /proc/1/cmdline
cat /proc/1/status
cat /proc/self/status
cat /proc/meminfo

## private key search

all different exec_id -> 4 different occurence grep active and apiservice kicker
13:35:18.690604774Z 
13:35:18.889060213Z
13:35:23.932332227Z
13:35:24.137402066Z


no sensetive read

| Result                                      | Count |
| ------------------------------------------- | ----: |
| Scenario-related `terminal-shell-container` | **1** |
| Unrelated `private-key-search`              | **4** |
| Unrelated `sensitive-read-untrusted`        | **0** |
| **Total scenario-related**                  | **1** |
| **Total unrelated**                         | **4** |
| **Total occurrences**                       | **5** |
