START  2026-09-09T20:18:31.356Z
END    2026-09-09T20:19:12.769Z
EXIT   0

old
IP  = 10.1.235.191
new

52 raw policy records

| Policy                     | Raw records | Reconstructed occurrences |
| -------------------------- | ----------: | ------------------------: |
| `private-key-search`       |          23 |                        23 |
| `sensitive-read-untrusted` |          20 |                         1 |
| `terminal-shell-container` |           6 |                         6 |
| `k8s-api-contact`          |           2 |                         2 |
| `directory-traversal-read` |           1 |                         1 |
| **Total**                  |      **52** |                    **33** |


17 scenario-related
16 unrelated
33 total occurrences


k8s-api-contact 2

20:18:38.520Z
worker1
mariadb-galera-0
container = init
/bin/mariadb-operator init galera

10.1.235.130 → 10.152.183.1:443 -> make tcp conneciton


20:19:08.026Z
worker1
mariadb-galera-0
container = agent
/bin/mariadb-operator agent galera
also make tcp

terminal-shell-container:

how in 1 run pre and prost check = 2

4 galers recovery


prvoate key 

8 scenario + 15 unrealted

8 from joiner and donore
15 apikicker

directory-traversal-read: related during recover<a>
/sys/dev/block/8:1/../queue/physical_block_size 


| Policy                     | Scenario-related | Unrelated |
| -------------------------- | ---------------: | --------: |
| `terminal-shell-container` |            **6** |         0 |
| `private-key-search`       |            **8** |        15 |
| `k8s-api-contact`          |            **2** |         0 |
| `directory-traversal-read` |            **1** |         0 |
| `sensitive-read-untrusted` |                0 |         1 |
| **Total**                  |           **17** |    **16** |
