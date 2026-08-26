1. ## (tetragon-falco-reference-v4-candidate-run-shell.yaml) with partents
### security_bprm_check + matchParentBinaries

security_bprm_check - äто Linux Security Module hook, который вызывается во время exec до того, как новая программа полностью заменит текущий процесс.

runc
  ↓
хочет выполнить /bin/sh
  ↓
security_bprm_check("/bin/sh")
  ↓
если всё разрешено
  ↓
процесс становится /bin/sh

### tests:
Мы хотели проверить, что новая candidate-policy не реагирует на любой обычный sh, а только когда shell запускается из нужного protected parent.

обычный Kubernetes Job
        ↓
runc
        ↓
/bin/sh
        ↓
parent НЕ nginx/mysqld/postgres/...
        ↓
candidate НЕ срабатывает

negative test failed


2. ## tetragon-falco-reference-v4-candidate-run-shell-current-binary.yaml
### sys_execve + matchBinaries:


execve("/bin/sh")
AND
current binary that calls execve = protected application

Почему:
matchBinaries в Tetragon фильтрует binary процесса, который совершает syscall.
Что хотим получить:

nginx
  ↓
execve("/bin/sh")
  ↓
MATCH

То есть неожидано в nginx открылся shell, и должно сработать правило


Tests:

Negative:  PASST
обычный Kubernetes container
runc → execve("/bin/sh")

current binary = runc
→ не match


Positive PASST:

current binary = nginx/mysqld/...
→ match

Подробнее:
protected application
      ↓
execve("/bin/sh")
      ↓
candidate ДОЛЖНА сработать





