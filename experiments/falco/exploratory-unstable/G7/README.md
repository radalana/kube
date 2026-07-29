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

Associated phase:
G6 Pod deletion and recovery

Classification:
benign security alert / operational false positive

### Run: 02

Scenario completed successfully: yes
Falco restart during scenario: no

Falco alerts observed: 2
Scenario-related alerts: 2

Rule:
Unexpected connection to K8s API Server from container

Observed processes:
mariadb-operator init galera
mariadb-operator agent galera

Associated phase:
G6 Pod deletion and recovery

Classification:
benign security alert / operational false positive

### Run: 03

Scenario completed successfully: yes
Falco restart during scenario: yes

Result:
invalid

Reason:
Falco terminated during the scenario execution window after a syscall
event parsing error involving an openat2 event. Because Falco restarted
during the run, continuous event collection for the complete scenario
window could not be guaranteed.


### Run: 04

Scenario completed successfully: no
Falco restart during scenario: no   # только если это действительно проверено

Result:
invalid

Reason:
The G3 backup Job failed while G2 and G3 were executed concurrently.
The backup attempted to inspect the temporary g2_migration_test table after
it had been removed by the schema migration scenario. G7 therefore terminated
before the G6 phase.


### Run: 05

Scenario completed successfully: yes
Falco restart during scenario: no

Falco alerts observed: 2
Scenario-related alerts: 2

Rule:
Unexpected connection to K8s API Server from container

Observed processes:
mariadb-operator init galera
mariadb-operator agent galera

Associated phase:
G6 Pod deletion and recovery

Classification:
benign security alert / operational false positive



Валидные:

run-01
run-02
run-05

Исключённые:

run-03 → invalid, Falco restart
run-04 → invalid, G3 backup failure