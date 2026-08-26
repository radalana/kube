falco-ref-kernel-module уже довольно близко воспроизводит Falco rule.
Попытка загрузить kernel module из контейнера.


Falco Linux Kernel Module Injection Detected как работает фалко:
init_module OR finit_module
AND
container
AND
effective CAP_SYS_MODULE
AND
container image не находится в allowlist

Моя v3.2

sys_init_module OR sys_finit_module
AND
Mnt != host_ns
AND
Effective CAP_SYS_MODULE

kernel-module

Decision: KEEP
Mapping status: close

Official Tetragon alternative:
reviewed, not adopted

Reason:
The official modules.yaml implements a broader kernel-module
audit mechanism and does not reproduce the container,
CAP_SYS_MODULE, and syscall-specific conditions of the
Falco reference rule.

The existing mapping more closely reproduces the Falco
detection semantics.