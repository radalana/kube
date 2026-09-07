occurred within the scenario window but before the G2 workload process started and its process context matched the recurring MicroK8s background pattern -> occurred before the scenario


19:09:42.989Z – 19:09:48Z 

Have different exec_id, on master node
1. falco-ref-private-key-search 19:09:44.868 
2. falco-ref-private-key-search 19:09:45.065 

## Timiing
scenario window starts
19:09:42.989
        ↓
private-key-search occurrence 1 on master
~19:09:44.868
        ↓
private-key-search occurrence 2 on master
~19:09:45.065
        ↓
G2 workload process actually starts on worker2
/usr/bin/sh ~19:09:46.126
/usr/bin/mariadb ~19:09:46.128
        ↓
scenario window ends
19:09:48


process_kprobe:
current process = /usr/bin/bash
arguments       = .../apiservice-kicker
function        = __x64_sys_execve
target          = .../bin/grep
policy          = private-key-search

what happende: 
apiservice-kicker
      ↓
execve(.../grep)
      ↓
process_exec
grep active    