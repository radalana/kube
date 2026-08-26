memfd-exec-stage
Decision: KEEP
Mapping status: partial

Reason:
The v3.2 TracingPolicy observes memfd_create and execveat independently
and is therefore broader than the Falco rule.

Official Tetragon alternative:
VALIDATED

Validation:
With enableProcessCred enabled, a controlled memfd execution produced
process_exec with binary=/dev/fd/3 and
binary_properties.file.inode.links=0.

Limitation:
The official indicator is exposed through process observability and
cannot be used directly as a Tetragon v1.7.0 TracingPolicy selector.

### SUMMA>RY: possible but not with policy, with filteration,not scope, this is why keep old v3.2

memfd-exec-stage - для обнаружения fileless execution, то есть запуска программы без обычного исполняемого файла на диске.
Принуцип работы fileless execution:
memfd_create()
       ↓
создаётся anonymous file
       ↓
в него записывается executable
       ↓
execveat() -> Это syscall. execveat(7, "", ..., AT_EMPTY_PATH), AT_EMPTY_PATH - используй сразу объект на который указывает fd 7
       ↓
программа запускается

Зачем программа отслеживает.
Для обычного вредоносного файла защитное средство может увидеть: /tmp/malware и проверить его как файл.



и проверить его как файл.
Поэтому такой механизм может использоваться, например, чтобы выполнить загруженный payload, не сохраняя его как обычный executable на disk.

Сейчас в v3.2 широкая состоит из 2-ух независимыз наблюдений:
1-ый хук
 sys_memfd_create
   → кто-то вызвал memfd_create()
   → MATCH

ИЛИ

2-ой хук
 sys_execveat
   → кто-то вызвал execveat()
   → MATCH

Как хотим заменить?
Candidate basis: Tetragon Fileless Execution observability
Есть замена Tetragon есть более подходящий официальный механизм для Fileless Execution сам факт выполнения binary без обычной filesystem link

1. нужно менять конфиг тетрагона для этого проверить конфигурацчию enableProcessCred: true (у меня был false)
 get values tetragon -n kube-system -a | >> Select-String "enableProcessCred"

так же проверить
2. k get configmap tetragon-config -n kube-system `            
>>   -o jsonpath='{.data.enable-process-cred}'


Не нужно отдельной полиси.
Теперь проверяем официальный механизм Fileless Execution. В документации Tetragon для этого отдельная TracingPolicy не нужна: достаточно стандартного process_exec; при fileless execution ожидается binary_properties.file.inode.links = 0 https://tetragon.io/docs/policy-library/observability/


k get pods -n kube-system `
  -l app.kubernetes.io/name=tetragon `
  -o wide
NAME             READY   STATUS    RESTARTS   AGE   IP         NODE      NOMINATED NODE   READINESS GATES
tetragon-9mjvv   2/2     Running   0          14s   10.0.0.3   worker1   <none>           <none>
tetragon-mhzx5   2/2     Running   0          7s    10.0.0.4   worker2   <none>           <none>
tetragon-sxcw2   2/2     Running   0          11s   10.0.0.2   master    <none>           <none>

k get configmap tetragon-config -n kube-system `
  -o jsonpath='{.data.enable-process-cred}'
true

PS C:\Users\sveta\Documents\kube> k get configmap tetragon-config -n kube-system `            
>>   -o jsonpath='{.data.enable-process-cred}'
true
PS C:\Users\sveta\Documents\kube> ^C
PS C:\Users\sveta\Documents\kube> k exec -n kube-system tetragon-9mjvv -c tetragon -- `       
>>   sh -c 'rm -f /tmp/memfd-v4-w1.txt /tmp/memfd-v4-w1.err; nohup timeout 90s tetra getevents > /tmp/memfd-v4-w1.txt 2> /tmp/memfd-v4-w1.err &'
PS C:\Users\sveta\Documents\kube> 
PS C:\Users\sveta\Documents\kube> k exec -n kube-system tetragon-mhzx5 -c tetragon -- `
>>   sh -c 'rm -f /tmp/memfd-v4-w2.txt /tmp/memfd-v4-w2.err; nohup timeout 90s tetra getevents > /tmp/memfd-v4-w2.txt 2> /tmp/memfd-v4-w2.err &'
PS C:\Users\sveta\Documents\kube> 
PS C:\Users\sveta\Documents\kube> k exec -n kube-system tetragon-sxcw2 -c tetragon -- `
>>   sh -c 'rm -f /tmp/memfd-v4-master.txt /tmp/memfd-v4-master.err; nohup timeout 90s tetra getevents > /tmp/memfd-v4-master.txt 2> /tmp/memfd-v4-master.err &'
PS C:\Users\sveta\Documents\kube> k delete pod memfd-v4-test -n default --ignore-not-found    
PS C:\Users\sveta\Documents\kube> k run memfd-v4-test `                                   
>>   -n default `
>>   --image=python:3.14-slim `
>>   --restart=Never `
>>   --command -- python -c 'import os; assert os.execve in os.supports_fd; fd=os.memfd_create("tetragon-memfd-test",0); data=open("/usr/local/bin/python3","rb").read(); os.write(fd,data); os.fchmod(fd,0o755); os.lseek(fd,0,0); os.execve(fd,["python3","-c","print(\"memfd-exec-ok\")"],os.environ.copy())'
pod/memfd-v4-test created
PS C:\Users\sveta\Documents\kube> k get pod memfd-v4-test -n default -o wide              
NAME            READY   STATUS      RESTARTS   AGE   IP             NODE      NOMINATED NODE   READINESS GATES
memfd-v4-test   0/1     Completed   0          7s    10.1.235.171   worker1   <none>           <none>
PS C:\Users\sveta\Documents\kube> 
PS C:\Users\sveta\Documents\kube> k logs memfd-v4-test -n default           
memfd-exec-ok
PS C:\Users\sveta\Documents\kube> 


Как проверили:

*Документация Tetragon сама показывает его через фильтрацию обычных process_exec событий с jq; пример с /proc/self/fd/3 также имеет links: 0
Но это не полиси а фильтрация!

{
  "process_exec": {
    "process": {
      "exec_id": "d29ya2VyMToyNTk0NzcwNTU3MzM2NTIzOjE2MTg2MDA=",
      "pid": 1618600,
      "uid": 0,
      "cwd": "/",
      "binary": "/dev/fd/3",
      "arguments": "-c print(\"memfd-exec-ok\")",
      "flags": "execve rootcwd inInitTree",
      "start_time": "2026-08-26T15:53:50.630901368Z",
      "auid": 4294967295,

      "pod": {
        "namespace": "default",
        "name": "memfd-v4-test",
        "uid": "ce8a09bb-c1ff-4c58-bad6-ce46830c3e13",

        "container": {
          "id": "containerd://a247b1bf28380ef8593a1b53983f9f2408e4841a4c058d60b5acc89caf502f81",
          "name": "memfd-v4-test",

          "image": {
            "id": "docker.io/library/python@sha256:83ff1d245a3d57d04152252d3ef9cb361494d0b3395abd65a5ebe91c401c8e83",
            "name": "docker.io/library/python:3.14-slim"
          },

          "pid": 1,
          "security_context": {}
        },

        "pod_labels": {
          "run": "memfd-v4-test"
        },

        "workload": "memfd-v4-test",
        "workload_kind": "Pod"
      },

      "docker": "a247b1bf28380ef8593a1b53983f9f2",

      "parent_exec_id": "d29ya2VyMToyNTk0NzcwNTM5MDE1Njg1OjE2MTg2MDA=",

      "refcnt": 1,

      "cap": {
        "permitted": [
          "CAP_CHOWN",
          "DAC_OVERRIDE",
          "CAP_FOWNER",
          "CAP_FSETID",
          "CAP_KILL",
          "CAP_SETGID",
          "CAP_SETUID",
          "CAP_SETPCAP",
          "CAP_NET_BIND_SERVICE",
          "CAP_NET_RAW",
          "CAP_SYS_CHROOT",
          "CAP_MKNOD",
          "CAP_AUDIT_WRITE",
          "CAP_SETFCAP"
        ],

        "effective": [
          "CAP_CHOWN",
          "DAC_OVERRIDE",
          "CAP_FOWNER",
          "CAP_FSETID",
          "CAP_KILL",
          "CAP_SETGID",
          "CAP_SETUID",
          "CAP_SETPCAP",
          "CAP_NET_BIND_SERVICE",
          "CAP_NET_RAW",
          "CAP_SYS_CHROOT",
          "CAP_MKNOD",
          "CAP_AUDIT_WRITE",
          "CAP_SETFCAP"
        ]
      },

      "tid": 1618600,

      "process_credentials": {
        "uid": 0,
        "gid": 0,
        "euid": 0,
        "egid": 0,
        "suid": 0,
        "sgid": 0,
        "fsuid": 0,
        "fsgid": 0
      },
#### beweis
      "binary_properties": {
        "file": {
          "inode": {
            "number": "9617",
            "links": 0  # no file
          }
        }
      },

#### -----

      "in_init_tree": true
    },

    "parent": {
      "exec_id": "d29ya2VyMToyNTk0NzcwNTM5MDE1Njg1OjE2MTg2MDA=",
      "pid": 1618600,
      "uid": 0,
      "cwd": "/",
      "binary": "/usr/local/bin/python",

      "arguments": "-c \"import os; assert os.execve in os.supports_fd; fd=os.memfd_create(\"tetragon-memfd-test\",0); data=open(\"/usr/local/bin/python3\",\"rb\").read(); os.write(fd,data); os.fchmod(fd,0o755); os.lseek(fd,0,0); os.execve(fd,[\"python3\",\"-c\",\"print(\\\"memfd-exec-ok\\\")\"],os.environ.copy())\"",

      "flags": "execve rootcwd clone inInitTree",
      "start_time": "2026-08-26T15:53:50.612580480Z",
      "auid": 4294967295,

      "pod": {
        "namespace": "default",
        "name": "memfd-v4-test",
        "uid": "ce8a09bb-c1ff-4c58-bad6-ce46830c3e13",

        "container": {
          "id": "containerd://a247b1bf28380ef8593a1b53983f9f2408e4841a4c058d60b5acc89caf502f81",
          "name": "memfd-v4-test",

          "image": {
            "id": "docker.io/library/python@sha256:83ff1d245a3d57d04152252d3ef9cb361494d0b3395abd65a5ebe91c401c8e83",
            "name": "docker.io/library/python:3.14-slim"
          },

          "pid": 1,
          "security_context": {}
        },

        "pod_labels": {
          "run": "memfd-v4-test"
        },

        "workload": "memfd-v4-test",
        "workload_kind": "Pod"
      },

      "docker": "a247b1bf28380ef8593a1b53983f9f2",

      "parent_exec_id": "d29ya2VyMToyNTk0NzcwNDA5NDM1MjE0OjE2MTg1NTE=",

      "cap": {
        "permitted": [
          "CAP_CHOWN",
          "DAC_OVERRIDE",
          "CAP_FOWNER",
          "CAP_FSETID",
          "CAP_KILL",
          "CAP_SETGID",
          "CAP_SETUID",
          "CAP_SETPCAP",
          "CAP_NET_BIND_SERVICE",
          "CAP_NET_RAW",
          "CAP_SYS_CHROOT",
          "CAP_MKNOD",
          "CAP_AUDIT_WRITE",
          "CAP_SETFCAP"
        ],

        "effective": [
          "CAP_CHOWN",
          "DAC_OVERRIDE",
          "CAP_FOWNER",
          "CAP_FSETID",
          "CAP_KILL",
          "CAP_SETGID",
          "CAP_SETUID",
          "CAP_SETPCAP",
          "CAP_NET_BIND_SERVICE",
          "CAP_NET_RAW",
          "CAP_SYS_CHROOT",
          "CAP_MKNOD",
          "CAP_AUDIT_WRITE",
          "CAP_SETFCAP"
        ]
      },

      "tid": 1618600,

      "process_credentials": {
        "uid": 0,
        "gid": 0,
        "euid": 0,
        "egid": 0,
        "suid": 0,
        "sgid": 0,
        "fsuid": 0,
        "fsgid": 0
      },

      "in_init_tree": true
    },

    "node_name": "worker1",
    "time": "2026-08-26T15:53:50.630901548Z",

    "node_labels": {
      "beta.kubernetes.io/arch": "amd64",
      "beta.kubernetes.io/os": "linux",
      "kubernetes.io/arch": "amd64",
      "kubernetes.io/hostname": "worker1",
      "kubernetes.io/os": "linux",
      "microk8s.io/cluster": "true",
      "node.kubernetes.io/microk8s-worker": "microk8s-worker"
    }
  }
}


Python process
PID 1618600
        ↓
memfd_create("tetragon-memfd-test")
        ↓
falco-ref-memfd-exec-stage match
        ↓
execveat(fd=3, filename="", flags=4096)
        ↓
falco-ref-memfd-exec-stage match
        ↓
process_exec
binary = /dev/fd/3
        ↓
binary_properties.file.inode.links = 0

"binary":"/dev/fd/3",
"binary_properties":{
  "file":{
    "inode":{
      "number":"9617",
      "links":0
    }
  }
}


КАК было сделано: 
1. @"
tetragon:
  enableProcessCred: true
"@ | Set-Content `
  .\experiments\tetragon\install\v4-candidate\tetragon-process-cred-values.yaml

2. helm upgrade tetragon cilium/tetragon `
  --version 1.7.0 `
  -n kube-system `
  --reuse-values `
  -f .\experiments\tetragon\install\v4-candidate\tetragon-process-cred-values.yaml `
  --rollback-on-failure `
  --wait `
  --timeout 5m