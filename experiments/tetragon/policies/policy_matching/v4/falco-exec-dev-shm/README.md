exec-dev-shm (уже помечена partial)

Что это?
нужна для обнаружения запуска программы из /dev/shm

Что такое /dev/shm?
/dev/shm - конкретная временная директория в Linux типа tmpf. /dev/shm предназначена для shared memory между процессами


Что такое tmpf?
тип файловой системы и он смонтирован в /dev/shm

Почему security relevant?
Злоумышлиник может положить туда программу, потому что после reboot исчезнит, но необычное место для запуска executable


Что сейчас делает v3.2

execve("/dev/shm/...")
→ match

execveat(..., "/dev/shm/...", ...)
→ match


Falco видит шире

Пример:
cd /dev/shm
./payload

то фалко видит относительный путь, а тетрагон v3.2 увидет filename = "./payload" -> Prefix "/dev/shm/" = false

### first candidate (failed wegen security ingux module hooks)
Кандидат:
При этом у Tetragon есть более подходящий низкоуровневый механизм: на bprm_check_security можно получить аргумент типа linux_binprm, а Tetragon извлекает из него полный путь реально исполняемого файла. В документации v1.7.0 этот тип уже поддерживается.
https://raw.githubusercontent.com/cilium/tetragon/v1.7.0/docs/content/en/docs/concepts/tracing-policy/selectors.md

Цель что тетрагон умеет извелкать из хука bprm_check_security аргумент linux_binprm, и можно вытащить весь путь

Имплмементация:

1. Проверяем на одной ноде что присутсвует нужный хук (в данном случае worker1):

ssh worker1 "grep -E 'security_bprm_check|bprm_check_security' /proc/kallsyms | head"
PS C:\Users\sveta\Documents\kube> ssh worker1 "grep -E 'security_bprm_check|bprm_check_security' /proc/kallsyms | head"
0000000000000000 W __pfx_bpf_lsm_bprm_check_security
0000000000000000 W bpf_lsm_bprm_check_security  <- использованный lsm хук для кандидата 1
0000000000000000 T __pfx_security_bprm_check
0000000000000000 T security_bprm_check                           <-реальная функуия линукса
0000000000000000 t __pfx_tomoyo_bprm_check_security
0000000000000000 t tomoyo_bprm_check_security
0000000000000000 T __pfx_ipe_bprm_check_security
0000000000000000 T ipe_bprm_check_security
0000000000000000 T __SCT__lsm_static_call_bprm_check_security_0
0000000000000000 T __SCT__lsm_static_call_bprm_check_security_1

3. проверка синтаксиса и тп:
k apply `
  -f .\experiments\tetragon\policies\policy_matching\v4\falco-exec-dev-shm\candidate\tetragon-falco-reference-v4-candidate-exec-dev-shm.yaml `
  --dry-run=server
tracingpolicy.cilium.io/falco-ref-exec-dev-shm-v4-candidate created (server dry run)
4. запуск политики 
k apply `
  -f .\experiments\tetragon\policies\policy_matching\v4\falco-exec-dev-shm\candidate\tetragon-falco-reference-v4-candidate-exec-dev-shm.yaml
tracingpolicy.cilium.io/falco-ref-exec-dev-shm-v4-candidate created

5. Проверка:
    5.1. 
        k get tracingpolicy falco-ref-exec-dev-shm-v4-candidate
    PS C:\Users\sveta\Documents\kube> k get tracingpolicy falco-ref-exec-dev-shm-v4-candidate
    NAME                                  AGE
    falco-ref-exec-dev-shm-v4-candidate   41s

    5.2 find out pod name
        $tp = k get pod -n kube-system `
  -l app.kubernetes.io/name=tetragon `
  --field-selector spec.nodeName=worker1 `
  -o jsonpath='{.items[0].metadata.name}'
PS C:\Users\sveta\Documents\kube> tetragon-rnrjs

    5.3 log check inside this pod
    k logs -n kube-system $tp -c tetragon --since=2m |
  Select-String "falco-ref-exec-dev-shm-v4-candidate|error|failed"

level=info msg="adding tracing policy" name=falco-ref-exec-dev-shm-v4-candidate 
info="falco-ref-exec-dev-shm-v4-candidate (object:1/5456c761-8ac1-49d1-9bdf-6c9099045cc6) (type:/)"
level=warn msg="adding tracing policy failed" error="policy handler 'tracing' failed loading policy 
'falco-ref-exec-dev-shm-v4-candidate': does you kernel support the bpf LSM? You can enable LSM BPF by 
modifyingthe GRUB configuration /etc/default/grub with GRUB_CMDLINE_LINUX=\"lsm=bpf\""

в чем проблема:
bprm_check_security это bpf LSM, то есть защищенный хук, нужно включать через GRUB kernel boot configuration не включён BPF LSM

https://github.com/cilium/tetragon/blob/main/docs/content/en/docs/concepts/tracing-policy/selectors.md?utm_source=chatgpt.com



### второй кандидат через kprobe
What is difference?
hook - point of kernel
kprobe on of the way how to attch to it

Здесь Tetragon использует официальный LSM attach mechanism. То есть eBPF-программа становится участником LSM hook chain.

Кандидат 2: kprobe

Схема где именно Tetragon подключается к Linux kernel 
Linux exec
   ↓
kernel вызывает функцию security_bprm_check(...)
   ↓
kprobe стоит на входе в эту функцию
   ↓
Tetragon получает event

#### Как работает policy:
Схема что делает TravingPolicy после подключения к этой функции:
security_bprm_check
+
linux_binprm : structure in Linux Kernel, тут это аргуемент функции security_bprm_check, из этой структуры тетрагон получает path=/dev/shm/
+
resolved path starts with /dev/shm/ и тут проверяет path starts with /dev/shm/?

Implenetation:

1. check if crd accept it:
k apply -f .\experiments\tetragon\policies\policy_matching\v4\falco-exec-dev-shm\candidate\candidate-exec-dev-shm-kprobe.yaml --dry-run=server tracingpolicy.cilium.io/falco-ref-exec-dev-shm-v4-kprobe-candidate created (server dry run)

2. deploy candidate
k apply `
  -f .\experiments\tetragon\policies\policy_matching\v4\falco-exec-dev-shm\candidate\candidate-exec-dev-shm-kprobe.yaml

3. check if exists
  k get tracingpolicy falco-ref-exec-dev-shm-v4-kprobe-candidate

4. check if on worker1
PS C:\Users\sveta\Documents\kube> $tp = k get pod -n kube-system `
>>   -l app.kubernetes.io/name=tetragon `
>>   --field-selector spec.nodeName=worker1 `
>>   -o jsonpath='{.items[0].metadata.name}'
PS C:\Users\sveta\Documents\kube> 
PS C:\Users\sveta\Documents\kube> k logs -n kube-system $tp -c tetragon --since=2m |
>>   Select-String "falco-ref-exec-dev-shm-v4-kprobe-candidate|error|failed"


### Tests
Срабатывает ли policy именно тогда, когда реально выполняется файл из /dev/shm, и не срабатывает ли на обычный файл вне /dev/shm.

#### Positive test
2 pods:
one pod execute file with absoulute path /dev/shm/busybox  (v3.2 could do it already)
second with relative cd /dev/shm
./busybox echo relative-exec-ok     -> fix from v3.2 


5. start raw capture on worker1 

PS C:\Users\sveta\Documents\kube> k exec -n kube-system $tp -c tetragon -- `
>>   sh -c 'rm -f /tmp/exec-dev-shm-v4.txt /tmp/exec-dev-shm-v4.err; nohup timeout 120s tetra getevents > /tmp/exec-dev-shm-v4.txt 2> /tmp/exec-dev-shm-v4.err &'


required: 2 controlled Pods on worker1 with emptyDir: medium: Memory - wozu? bedeutet создай временный volume как tmpfs, то есть в RAM, а не на диске ноды

6.

@"
apiVersion: v1
kind: Pod
metadata:
  name: exec-dev-shm-absolute
  namespace: default
spec:
  nodeName: worker1
  restartPolicy: Never
  containers:
    - name: test
      image: alpine:3.22
      command:
        - /bin/sh
        - -c
        - |
          cp /bin/busybox /dev/shm/busybox
          chmod +x /dev/shm/busybox
          /dev/shm/busybox echo absolute-exec-ok
      volumeMounts:
        - name: shm
          mountPath: /dev/shm
  volumes:
    - name: shm
      emptyDir:
        medium: Memory
---
apiVersion: v1
kind: Pod
metadata:
  name: exec-dev-shm-relative
  namespace: default
spec:
  nodeName: worker1
  restartPolicy: Never
  containers:
    - name: test
      image: alpine:3.22
      command:
        - /bin/sh
        - -c
        - |
          cp /bin/busybox /dev/shm/busybox
          chmod +x /dev/shm/busybox
          cd /dev/shm
          ./busybox echo relative-exec-ok
      volumeMounts:
        - name: shm
          mountPath: /dev/shm
  volumes:
    - name: shm
      emptyDir:
        medium: Memory
"@ | k apply -f -



#### Negative Test
Программа запускается но не из /dev/shm, и НЕ должно быть матча

7. start capture
k exec -n kube-system $tp -c tetragon -- `
  sh -c 'rm -f /tmp/exec-dev-shm-neg.txt /tmp/exec-dev-shm-neg.err; nohup timeout 90s tetra getevents > /tmp/exec-dev-shm-neg.txt 2> /tmp/exec-dev-shm-neg.err &'

8. @"
apiVersion: v1
kind: Pod
metadata:
  name: exec-dev-shm-negative
  namespace: default
spec:
  nodeName: worker1
  restartPolicy: Never
  containers:
    - name: test
      image: alpine:3.22
      command:
        - /bin/sh
        - -c
        - |
          cp /bin/busybox /tmp/busybox
          chmod +x /tmp/busybox
          /tmp/busybox echo negative-exec-ok
"@ | k apply -f -


9. check
k logs exec-dev-shm-negative -n default

expected: negative-exec-ok

10. k cp `
  kube-system/${tp}:/tmp/exec-dev-shm-neg.txt `
  .\exec-dev-shm-neg.txt `
  -c tetragon
tar: removing leading '/' from member names




resullt
exec-dev-shm
Decision: MODIFY / partial

v4 implementation:
kprobe on security_bprm_check
+ linux_binprm
+ Prefix /dev/shm/

Validation:
absolute /dev/shm execution → MATCH
relative ./busybox from /dev/shm → MATCH
/tmp execution → NO MATCH