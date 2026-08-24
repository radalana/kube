| G1     | Runtime telemetry         | Policy detection |
| ------ | ------------------------- | ---------------- |
| run-01 | `sh`, `mariadb` exec/exit | 0                |
| run-02 | `sh`, `mariadb` exec/exit | 0                |
run-02      `sh`, `mariadb` exec/exit  0

etragon observed the execution of the G1 workload through process telemetry, but the active file-monitoring-filtered TracingPolicy generated no policy-based detection in any of the three valid runs.