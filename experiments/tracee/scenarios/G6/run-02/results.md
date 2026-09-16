Window:
09:42:11.654Z
09:42:45.130Z

| Classification   | Detection                            |  Count |
| ---------------- | ------------------------------------ | -----: |
| Scenario-related | `falco-ref-terminal-shell-container` |  **6** |
| Scenario-related | `falco-ref-k8s-api-contact`          |  **2** |
| Unrelated        | `falco-ref-clear-log`                | **45** |
| **Total**        |                                      | **53** |



# falco-ref-terminal-shell-container (scenario-related)
is not the same action:


## Galera check × 2:
worker1
pre recovery on old mariadb-galera-0 + after revofery on new mariadb-galera-0

## During Galera Recovery × 4:
shell actiivty launched by MariaDB itself:

### on master / mariadb-galera-1 × 2
sh
  -> wsrep_sst_mariabackup --role donor
bash
  -> wsrep_sst_mariabackup --role donor

### worker1 × 2
└── mariadb-galera-0
    ├── sh
    └── bash
        -> wsrep_sst_mariabackup --role joiner


all together process (*in run-01 also relevant):

worker1 / old mariadb-galera-0
  1 × sh
  pre-recovery Galera status check

master / mariadb-galera-1
  1 × sh
  1 × bash
  SST donor

worker1 / new mariadb-galera-0
  1 × sh
  1 × bash
  SST joiner

worker1 / new mariadb-galera-0
  1 × sh
  post-recovery Galera status check


# falco-ref-k8s-api-contact (scenario-related) × 2:
proof: also different container IDs
1 from new pod: init container contacts 10.152.183.1:443 (Kubernetes API) сразу при создании нового Pod
2 also from new pod: but agent container contacts 10.152.183.1:443 (Kubernetes API) позже, когда Pod уже проходил recovery / становился Ready

How process looked like together:

new mariadb-galera-0
│
├── init container
│   └── mariadb-operator init galera
│       └── connection to Kubernetes API
│           → falco-ref-k8s-api-contact #1
│
├── mariadb container
│
└── agent container
    └── mariadb-operator agent galera
        └── connection to Kubernetes API
            → falco-ref-k8s-api-contact #2

# falco-ref-clear-log (Unrelated) × 45

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
journal files

distribution:
master:   27
worker1:  15
worker2:   3


also relevenat for run-01
Ground truth:
  pre Galera: 3 / Synced
  old UID: 30c2000c...
  new UID: 2675dcb6...
  recreated Pod Ready
  post Galera: 3 / Synced
  node remained worker1
  Tracee stable


* in master stream: 
racee сообщений error reading argument from buffer для sched_process_exit. Они не имеют matchedPolicies -> но перезапусков не было, значит согасно критериям ран остается валид