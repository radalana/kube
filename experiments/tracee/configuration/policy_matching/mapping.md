| Falco rule             | Tracee detection     | Status | Decision | Notes |
| ---------------------- | -------------------- | ------ | -------- | ----- |
| Run shell untrusted    | `illegitimate_shell` | TODO   | TODO     |       |
| Contact K8s API Server | `k8s_api_connection` | partial|keep      | Similar activity is detected, but matching conditions differ; requires `exec-env: true`      |
| Fileless execution     | `fileless_execution` | TODO   | TODO     |       |
