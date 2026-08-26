### List
| Policy                             | Что планировали                                                                                                        |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `run-shell-untrusted`              | **MODIFY** — слишком широкая, ловила любой shell. Это мы сейчас и исправляем                                           |
| `terminal-shell-container`         | **проверить/улучшить** — точнее учитывать TTY/interactive context                                                      |
| `stdio-network-redirect`           | **MODIFY** — сейчас не проверяет, что source FD действительно network socket; G2 показал проблему                      |
| `k8s-api-contact`                  | **проверить/адаптировать** — официальный Tetragon network mechanism есть, но его egress-пример не равен Falco semantic |
| `kernel-module`                    | **проверить замену/адаптацию** на официальный Tetragon `modules.yaml` mechanism                                        |
| `exec-dev-shm`                     | **проверить улучшение** через официальный binary-execution mechanism                                                   |
| `memfd-exec-stage`                 | **проверить replacement** на официальный Fileless Execution pattern                                                    |
| `private-key-search`               | **MODIFY/проверить** — текущая mapping довольно широкая                                                                |
| `aws-credential-search`            | **MODIFY/проверить** — тоже слишком широкая                                                                            |
| `ssh-nonstandard-port`             | проверить официальный Tetragon network/SSH pattern как основу                                                          |
| `directory-traversal-read`         | скорее **KEEP** как custom partial mapping                                                                             |
| `sensitive-read-trusted/untrusted` | скорее **KEEP**, но документировать partial semantics                                                                  |
| `clear-log`                        | **KEEP**, mapping близкая                                                                                              |
| `remove-bulk-data`                 | **KEEP**, близкая                                                                                                      |
| `symlink-sensitive`                | **KEEP**, близкая                                                                                                      |
| `hardlink-sensitive`               | **KEEP**, близкая                                                                                                      |
| `packet-socket`                    | **KEEP**, близкая                                                                                                      |
| `ptrace-attach`                    | **KEEP** после уже сделанной коррекции selectors                                                                       |
| `ptrace-antidebug`                 | скорее **KEEP**                                                                                                        |
| `netcat-rce`                       | скорее custom **KEEP**, если validation проходит                                                                       |
| `debugfs-privileged`               | partial, проверить, но не обязательно менять                                                                           |
| `release-agent`                    | partial, проверить, но не обязательно менять                                                                           |
