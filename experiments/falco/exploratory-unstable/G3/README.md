 k apply -f .\tests\scenarios\G3-backup\g3-backup.yaml    

Scenario completed successfully: yes
Falco restart during scenario: no
Falco alerts observed: 0
Scenario-related alerts: 0
Result: valid exploratory run

Scenario: G3 Authorized Logical Backup
Run: 02
Scenario completed successfully: yes
Falco restart during scenario: no
Falco alerts observed: 0
Scenario-related alerts: 0
Result: valid

Run 03
Scenario completed successfully: yes
Falco restart during scenario: no
Falco alerts observed: 0


cross three independent exploratory runs of G3, the authorized logical backup completed successfully without Falco restarts, and no Falco alerts were observed during the scenario windows.