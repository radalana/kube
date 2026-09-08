20:06:50.766Z – 20:07:00.748Z window
on worker1

| Policy                     | Raw records | Occurrences | Classification                      |
| -------------------------- | ----------: | ----------: | ----------------------------------- |
| terminal-shell-container |           1   |           1   | **scenario-related**                |
| private-key-search     |           4     |           4     | unrelated  (ambient pattern)                         |
| Total                       |       5    |       5    | 1 scenario-related, 4 unrelated |


20:06:56.551Z 
falco-ref-terminal-shell-container
target = /usr/bin/sh

prcoess -exec in 20:06:56.553Z

/usr/bin/sh
-c "id; hostname; ps"

Pod       = mariadb-galera-0
Namespace = database
Node      = worker1