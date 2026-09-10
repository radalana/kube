| Falco rule                     | Tracee detection             | Status | Decision | Notes |
| ---------------------- --------| --------------------         | ------ | -------- | ----- |
| Run shell untrusted            | `illegitimate_shell`         | TODO   | TODO     |       |
| Contact K8s API Server         | `k8s_api_connection`         | partial|keep      | Similar activity is detected, but matching conditions differ; requires `exec-env: true`|
| Fileless execution             | `fileless_execution`          | TODO   | TODO     |       |
|Falco STDIO/network redirection |stdio_over_socket             |partial | keep    | Falco watch redirection inside containers, Tracee bothe in containers and host -> broader
| Linux Kernel Module Injection Detected | kernel_module_loading | partial| keep | Falco wathces if modul kernel from container, tracee from both host and containers -> broader
|Debugfs Launched in Privileged Container|-no-ready-solution rule|unavailable|make custome policy?|No native tracee detection|