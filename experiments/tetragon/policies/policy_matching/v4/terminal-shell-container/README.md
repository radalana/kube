Что делает Falco:

spawned_process
AND container
AND shell_procs
AND proc.tty != 0   - у процесса есть привязанный terminal/TTY, поэтому раздичает не просто shell в контейнере, а что к shell подключен терминал
AND container_entrypoint
AND not user_expected_terminal_shell_in_container_conditions


Что сейчас делает Tetrgaon policy 3.2:

container approximation через Mnt != host_ns - что mount namespace процесса отличается от mount namespace хоста - использовалось как приближенное "process inside container"
AND namespace PID != 1 - то что дополнительный процесс контейнера запущен
AND target executable = sh/bash/dash/...  - что программа которую запустили это shell

т.е логика v3.2
процесс в отдельном mount namespace
→ вероятно контейнер

AND
это не PID 1 контейнера
→ не основной процесс контейнера

AND
запускается shell
→ sh/bash/dash/...

→ MATCH

## Имплементация

найти: kernel точку, через который тетрагон сможет получить признак что есть привязанный терминал как в Falco proc.tty != 0

Показать функции моего ядра, которые могут быть потенциально точ ками к котором тетрагон может привязаться 
1. k exec -n kube-system tetragon-vnc9n -c tetragon -- `
  sh -c 'grep -E "tty|pty" /proc/kallsyms | grep -E "tty_nr|tty_open|pty_open|tty_alloc|tty_init_dev" | head -30'

ответ:
ffffffff9e2bdff1 t tty_init_dev.part.0.cold
ffffffff9efb4d30 T __pfx___tty_alloc_driver
ffffffff9efb4d40 T __tty_alloc_driver
ffffffff9efb4ee0 T __pfx_tty_alloc_file
ffffffff9efb4ef0 T tty_alloc_file
ffffffff9efb5a30 t __pfx_tty_init_dev.part.0
ffffffff9efb5a40 t tty_init_dev.part.0
ffffffff9efb5c50 T __pfx_tty_init_dev
ffffffff9efb5c60 T tty_init_dev
ffffffff9efb5cb0 t __pfx_tty_open
ffffffff9efb5cc0 t tty_open
ffffffff9efb78b0 t __pfx_n_tty_open
ffffffff9efb78c0 t n_tty_open
ffffffff9efc0ab0 T __pfx_tty_open_proc_set_tty


ffffffff9efc0ac0 T tty_open_proc_set_tty    ### В Linux она связана с установкой controlling TTY для процесса; её prototype принимает struct file * и struct tty_struct *. https://github.com/torvalds/linux/blob/master/drivers/tty/tty.h?utm_source=chatgpt.com


ffffffff9efc1750 t __pfx_pty_open
ffffffff9efc1760 t pty_open
ffffffff9f2b5140 t __pfx_dbc_tty_open
ffffffff9f2b5150 t dbc_tty_open
ffffffffa01033bc r __ksymtab___tty_alloc_driver

2. k exec -n kube-system tetragon-vnc9n -c tetragon -- `
  sh -c 'grep -w "tty_nr" /proc/kallsyms | head'



tty_open_proc_set_tty hook показывает момент открытия/назначения terminal


1. https://falco.org/docs/reference/rules/supported-fields/?utm_source proc.tty как поле контекста процесса
Если Falco использует proc.tty, значит необходимая информация о controlling terminal существует в Linux и Falco умеет её извлекать. Это не означает, что существует отдельный kernel hook с той же семантикой или что Tetragon предоставляет эту информацию как готовый selector.

как работает фалко, сам превратил низкоуровневую информацию в удобное семантическое поле
kernel events
     ↓
Falco получает syscall/event information
     ↓
обогащает её process/fd/container state
     ↓
поддерживает внутренний context/cache
     ↓
предоставляет rule engine удобные поля


## почему нельзя proc.tty!= 0 написать в тетрагон
1. proc.tty поле фалко 


Именно поэтому я бы не заменяла одно другим в harmonization. Иначе мы технически сделаем policy более сложной, но семантически она станет другой detection. Linux действительно хранит TTY state и даже имеет функции вроде get_current_tty(), но это не означает, что Tetragon TracingPolicy предоставляет это состояние как готовый selector в момент execve.
https://github.com/torvalds/linux/blob/master/include/linux/tty.h

Для диплома это, кстати, очень хорошее объяснение того, почему “доступный kernel hook” ещё не означает “эквивалентное detection condition”.