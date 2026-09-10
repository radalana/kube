| Falco rule | Tracee detection | Status | Decision |
|---|---|---|---|
| Run shell untrusted | `illegitimate_shell` | TODO | TODO |
| Contact K8s API Server | `k8s_api_connection` | partial | keep |
| Fileless execution | `fileless_execution` | TODO | TODO |
| Falco STDIO/network redirection | `stdio_over_socket` | partial | keep |
| Linux Kernel Module Injection Detected | `kernel_module_loading` | partial | keep |
| Debugfs Launched in Privileged Container | -no-ready-solution rule | unavailable | make custome policy? |
| Detect release_agent File Container Escapes | `cgroup_release_agent` | partial | keep |
| PTRACE attached to process | `ptrace_code_injection` | partial | keep |
| PTRACE anti-debug attempt | `anti_debugging` | close | keep |
| Find AWS Credentials | none | unavailable | no mapping |
| Execution from /dev/shm | `fileless_execution` | partial | keep |
| Drop and execute new binary in container | `dropped_executable` | partial | keep |
| Disallowed SSH Connection Non Standard Port | none | unavailable | no mapping |
| Fileless execution via memfd_create | `fileless_execution` | partial | keep |

### Notes

**Contact K8s API Server**  
Similar activity is detected, but matching conditions differ; requires `exec-env: true`

**Falco STDIO/network redirection**  
Falco watch redirection inside containers, Tracee bothe in containers and host -> broader

**Linux Kernel Module Injection Detected**  
Falco wathces if modul kernel from container, tracee from both host and containers -> broader

**Debugfs Launched in Privileged Container**  
No native tracee detection

**Detect release_agent File Container Escapes**  
both watch release_agent in container, falco checks priviligeas etc.?? -> broader

**PTRACE attached to process**  
narrower  
Tracee covers `PTRACE_POKETEXT` and `PTRACE_POKEDATA`, but not Falco's `PTRACE_ATTACH`, `PTRACE_SEIZE`, or `PTRACE_SETREGS`.

**PTRACE anti-debug attempt**  
Both detect `ptrace` with `PTRACE_TRACEME`.

**Find AWS Credentials**  
No native Tracee 0.24.1 security detection for searching AWS credentials.

**Execution from /dev/shm**  
Tracee detects execution from `/dev/shm`, but also from `/run/shm` and `memfd`; Falco specifically targets `/dev/shm` and includes additional shell/cwd conditions.

**Drop and execute new binary in container**  
Related behavior, but Falco detects execution of an upper-layer executable, while Tracee detects an ELF executable being written into the container filesystem.

**Disallowed SSH Connection Non Standard Port**  
Tracee 0.24.1 has no native SSH-specific detection corresponding to this Falco rule.

**Fileless execution via memfd_create**  
Both cover execution from `memfd`, but Tracee also covers `/dev/shm` and `/run/shm` and does not reproduce Falco's `runc` exclusions.