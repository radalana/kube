Technical event: TRUE
Security rule matched: TRUE
Activity malicious: NO
Activity expected/authorized: YES
Operational investigation required: ideally NO

→ operational false positive / benign security alert


During G6, Falco generated alerts when MariaDB Operator components contacted the Kubernetes API server during Pod recovery.


G6 Pod Deletion and Recovery
### Run: 01

Scenario completed successfully: yes
Falco restart during scenario: no

Falco alerts observed: 2
Scenario-related alerts: 2

Rule:
Unexpected connection to K8s API Server from container

Observed processes:
mariadb-operator init galera
mariadb-operator agent galera

Classification:
benign security alert / operational false positive


### Run: 02

Falco alerts observed: 1
Scenario-related alerts: 1

Rule:
Unexpected connection to K8s API Server from container

Process:
mariadb-operator init galera

Classification:
benign security alert / operational false positive

Falco generated the same rule during all three G6 runs, triggered by MariaDB Operator recovery activity after Pod recreation. The number of individual alert events varied between runs.


### Run: 03

Scenario completed successfully: yes
Falco restart during scenario: no

Falco alerts observed: 2
Scenario-related alerts: 2

Rule:
Unexpected connection to K8s API Server from container

Observed processes:
mariadb-operator init galera
mariadb-operator agent galera

Classification:
benign security alert / operational false positive

## Galera check command
$sql = @"
SHOW STATUS LIKE 'wsrep_cluster_size';
SHOW STATUS LIKE 'wsrep_local_state_comment';
"@

$sql | k exec -i `
    -n database `
    mariadb-galera-0 `
    -c mariadb `
    -- sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"'