| Policy                     | RawRecords | UniqueExecIDs | Что это было                                                                                                      |
| -------------------------- | ---------: | ------------: | ----------------------------------------------------------------------------------------------------------------- |
| `sensitive-read-untrusted` |       1280 |            64 | `sshd-session` обращается к `/etc/pam.d/*`, ровно 20 records на execution                                         |
| `private-key-search`       |        688 |           688 | MicroK8s `apiservice-kicker` запускает `grep active`; private keys не ищутся                                      |
| `memfd-exec-stage`         |         18 |             3 | host `systemd` PID 1 вызывает `memfd_create("sd-executor-state")` парами примерно каждые 10 минут; `execveat` нет |
