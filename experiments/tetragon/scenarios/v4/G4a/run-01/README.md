09:51:29.775Z – 09:51:41.829Z

25 raw policy records -> after reconstruciton -> 6 detection occurence
| Policy                     | Raw records | Occurrences | Attribution                         |
| -------------------------- | ----------: | ----------: | ----------------------------------- |
| `terminal-shell-container` |           1 |           1 | **scenario-related**                |
| `private-key-search`       |           4 |           4 | unrelated                           |
| `sensitive-read-untrusted` |          20 |           1 | unrelated                           |
| **Total**                  |      **25** |       **6** | **1 scenario-related, 5 unrelated** |

1. terminal-shell-container

Policy event:
09:51:34.838 in time windows
worker1
falco-ref-terminal-shell-container
target = /usr/bin/sh

related process_execc shows that:
/usr/bin/sh
-c "id; hostname; ps"

Pod       = mariadb-galera-0
Namespace = database
Node      = worker1 

what means that it 100% belogns to scenario
G4a produced a scenario-related terminal-shell-container detection, although the executed shell was non-interactive and had no TTY.

policy name: terminal-shell-container
actual G4a:  non-interactive shell, TTY = нет такого поля в отлчие от фалко и можно ссылаться на policy matching -> proc.tty != 0

То есть полиси на запуск без темрина и сработала верно? или нет?, но она рсаботала когад серез -c то есть без самого терминалаа,. это объясняется ограничение partial mapping#

2. praivate key search 
same as in ambient:

MicroK8s apiservice-kicker
        ↓
grep active


and one of them os inside window (from 4)

3- sensetive read-untrastued - 20raw -> 1 occurence
allbelong to oneoricess

The terminal-shell-container match was attributable to G4a, but it did not indicate that an interactive terminal was present. The non-interactive shell had no TTY, showing that the evaluated Tetragon mapping also matched ordinary shell execution inside the container.