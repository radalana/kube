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
0000000000000000 W bpf_lsm_bprm_check_security
0000000000000000 T __pfx_security_bprm_check
0000000000000000 T security_bprm_check                           <-нужный хук найдет
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

