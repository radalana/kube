# G6 run-01

### Window 
START  2026-09-09T14:58:44.195Z
END    2026-09-09T14:59:25.466Z
EXIT   0

## Streams

| Node    | First         | Last          |
| ------- | ------------- | ------------- |
| master  | 14:58:29.139Z | 14:59:30.776Z |
| worker1 | 14:58:32.396Z | 14:59:31.095Z |
| worker2 | 14:58:35.870Z | 14:59:31.415Z |


| Policy                     | Raw records | Reconstructed occurrences | Related | Unrelated |
| -------------------------- | ----------: | ------------------------: |
| `sensitive-read-untrusted` |         180 |                         9 | 0            9
| `private-key-search`       |          24 |                        24 | 8            16
| `terminal-shell-container` |           6 |                         6 | 6 out 6
| `k8s-api-contact`          |           2 |                         2 | 2 out 2
| `directory-traversal-read` |           1 |                         1 |
| **Total**                  |     **213** |                    **42** | **17*  |     **25**


## k8s-api-contact
1.  14:58:49.825Z on worker1
### Process:
    /bin/mariadb-operator
        init galera
        Pod       = mariadb-galera-0
        Container = init

#### Connection
10.1.235.191 → 10.152.183.1:443 
Init container of new Pod talk to Kuber Api

2. 14:59:19.283Z

same
TODO: check kuber api ip adress  10.152.183.1 


2. time 14:59:19.283Z 

10.152.183.1 = kub api
same as 1.

## terminal-shell-container -insgesamt 6

1. 14:58:47.670Z pre check
2. 14:59:19.835Z post check

Both: belongs to galera check inside scenraio but was not caused by not pod recovery itself 

/usr/bin/sh -c ...  
→ mariadb client
→ mariadb-galera-0

state transfer: synchronize eeach other
worker 1: 1 or 2?                        
mariadbd 
→ /usr/bin/sh
→ wsrep_sst_mariabackup
→ bash
role = joiner

https://mariadb.com/docs/galera-cluster/reference/wsrep-variable-details/wsrep_sst_mariabackup
master:  -> 1 or 2?
mariadbd
→ /usr/bin/sh
→ wsrep_sst_mariabackup
→ bash
role = donor
| Время          | Node / Pod                             | Что запустилось  | Почему это произошло                             |
| -------------- | -------------------------------------- | ---------------- | ------------------------------------------------ |
| `14:58:47.670` | worker1 / `mariadb-galera-0`           | `/usr/bin/sh`    | **G6 pre-check**: `mariadb -uroot ...`           |
| `14:58:53.569` | worker1 / `mariadb-galera-0`           | `/usr//bin/sh`   | Galera recovery: запуск SST **joiner**           |
| `14:58:53.572` | worker1 / `mariadb-galera-0`           | `/usr//bin/bash` | SST script `wsrep_sst_mariabackup --role joiner` |
| `14:58:54.152` | master / `mariadb-galera-1`            | `/usr//bin/sh`   | Galera recovery: запуск SST **donor**            |
| `14:58:54.157` | master / `mariadb-galera-1`            | `/usr//bin/bash` | SST script `wsrep_sst_mariabackup --role donor`  |
| `14:59:19.835` | worker1 / recreated `mariadb-galera-0` | `/usr/bin/sh`    | **G6 post-check**: `mariadb -uroot ...`          |

what happens
G6 starts

├── pre Galera validation
│      └── sh                         # occurrence 1
│
├── delete mariadb-galera-0
│
├── Galera recovery
│      │
│      ├── mariadb-galera-0 (joiner)
│      │      ├── sh                  # occurrence 2
│      │      └── bash SST script     # occurrence 3
│      │
│      └── mariadb-galera-1 (donor)
│             ├── sh                  # occurrence 4
│             └── bash SST script     # occurrence 5
│
└── post Galera validation
       └── sh                         # occurrence 6


## private-key-search

24 occ

8 scenario rel

wsrep_sst_mariabackup makes grep 

new mariad db on worker 1  pod 6 mal grep smth   joiner
 mariadb-galera-1 on master grep more 2 times    donor


 SST activity


 16 unrelated

 grep aktive from apiservice kicker (ambient pattern)


 ## directirey traversal

 1 related 14:58:54.647Z on worker1 
 /usr/sbin/mariadbd
Pod = mariadb-galera-0 

target /sys/dev/block/8:1/../queue/physical_block_size  smth dircutng reocvery

## sensitive read untersted - 9 unrelated 

180 raw records 
9 ssh occurenc 
20 raw -> ambiwn t sshd

