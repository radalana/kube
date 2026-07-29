
.\tests\scenarios\G5-file-process-inspection\run-g5c-proc-read.ps1


.\tests\scenarios\G5-file-process-inspection\run-g5a-config-read.ps1 2>&1 |
  Tee-Object -FilePath "$run\g5a-output.txt"


## G5 config-read
### Run: 01

Scenario completed successfully: yes
Falco restart during scenario: no
Falco alerts observed: 0
Scenario-related alerts: 0
Result: valid

### Run: 02

Scenario completed successfully: yes
Falco restart during scenario: no
Falco alerts observed: 0
Scenario-related alerts: 0
Result: valid

### Run: 03

Scenario completed successfully: yes
Falco restart during scenario: no
Falco alerts observed: 0
Scenario-related alerts: 0
Result: valid



Summary:
All three runs completed successfully.
No Falco restarts occurred during the scenario windows.
No Falco alerts were observed in any of the three runs.