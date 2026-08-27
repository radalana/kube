private-key-search был partial

# Что делает Falco rule:
пытается заметить если кто-то использует grep or find чтобы найти приватные ключи или секреты

# Что делеает v3.2
Просто проверяет был ли запущен grep, egrep, fgrep, find, и все то есть слишком широкая.

# Что делает Фалко:
Спрашивает grep и аргументы процесса, если содержит id_ed25519 или BEGIN PRIVATE.

spawned_process
AND
(
   grep/egrep/fgrep
   AND args содержат один из:
      "BEGIN PRIVATE"
      "BEGIN OPENSSH PRIVATE"
      "BEGIN RSA PRIVATE"
      "BEGIN DSA PRIVATE"
      "BEGIN EC PRIVATE"

   OR

   find
   AND args содержат:
      id_rsa
      id_dsa
      id_ed25519
      id_ecdsa
)

# Почему трудно перенести в TracingPolicy
 у execve(filename, arg, envp), где argv это масси укзаателей

 НО Tetragon: нет селектора который бы делал process.arguments содержит строку "BEGIN PRIVATE KEY"
matchArgs
atchBinaries
matchNamespaces
matchCapabilities
matchActions

И вот теперь важное: для прямого переноса Falco proc.args в TracingPolicy есть проблема. matchArgs фильтрует аргументы выбранной kernel function, а execve имеет:

execve(filename, argv, envp)

где argv — это char **, массив строк. В документированных argument types Tetragon есть string, char_buf, char_iovec и т. д., но char_iovec относится к struct iovec, а не к char **argv; отдельного типа «argv vector» или selector по уже сформированному process.arguments нет.
https://tetragon.io/docs/reference/tracing-policy/?

## разница
Falco:
proc.args contains "BEGIN PRIVATE KEY"

Tetragon:
нет готового selector для process.arguments

### вывод

Официальная Policy Library тоже часто использует process_exec.process.arguments именно при post-processing событий, а не как TracingPolicy selector
https://tetragon.io/docs/policy-library/observability


Decision: KEEP / partial

Reason:
The v3.2 mapping detects execution of grep/egrep/fgrep/find,
but does not reproduce Falco's proc.args conditions.

A direct policy-level equivalent was not identified in the
documented Tetragon v1.7.0 selector model.

Tetragon exposes process arguments in process_exec,
but using them would require post-processing rather than
a TracingPolicy match.