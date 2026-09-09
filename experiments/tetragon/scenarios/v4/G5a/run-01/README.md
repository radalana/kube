G5a Run 01

START  2026-09-09T 10:56:  37.663  Z
END    2026-09-09T 10:56:  58.073  Z
EXIT   0


были прочитаны 
/etc/mysql/mariadb.cnf
/etc/mysql/mariadb.conf.d/0-galera.cnf

| Node    | First event   | Last event    |
| ------- | ------------- | ------------- |
| master  | 10:56:  19.138Z | 10:57: 01.184Z | -> in window
| worker1 | 10:56:  22.622Z | 10:57: 01.485Z |-> in window
| worker2 | 10:56:  30.944Z | 10:57: 01.795Z |-> in window


Occurence:
on worker1: 
10:56:50.820Z
falco-ref-terminal-shell-container
target = /usr/bin/sh

in 2 ms
/usr/bin/sh -c ...
Pod       = mariadb-galera-0
Namespace = database
Container = mariadb
Node      = worker1


terminal-shell-container but, detection был вызван execution /usr/bin/sh, которым реализован G5a, а не самим чтением MariaDB configuration files


| Result                               |  Count |
| ------------------------------------ | -----: |
| Scenario-related                     |  **1** |
| Unrelated `private-key-search`       |      8 | 8 records 8 occurence ambient pattern with grep active all on master
| Unrelated `sensitive-read-untrusted` |      4 | 80 raw records = 4 occurrences sshd ambient pattern all on master
| **Total unrelated**                  | **12** |
| **Total occurrences**                | **13** |
