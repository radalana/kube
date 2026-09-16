Window:
09:23:05.905Z
09:23:29.522Z

| Classification   | Detection                            |  Count |
| ---------------- | ------------------------------------ | -----: |
| Scenario-related | `falco-ref-terminal-shell-container` |  **6** |
| Scenario-related | `falco-ref-k8s-api-contact`          |  **2** |
| Unrelated        | `falco-ref-clear-log`                | **39** |
| **Total**        |                                      | **47** |


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



# falco-ref-k8s-api-contact (scenario-related):

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

# falco-ref-clear-log (Unrelated) × 39

falco-ref-clear-log
systemd-journal
do_truncate / ftruncate
journal files

distribution:

master:   21
worker1:  16
worker2:   2



* Есть также Tracee diagnostic сообщения вида unsupported runtime containerd, но у них нет matchedPolicies, поэтому это не detections и  не считаем. (maybe in discussions)