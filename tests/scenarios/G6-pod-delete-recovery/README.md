1. Проверить состояние MariaDB Galera до удаления Pod
2. Удалить Pod mariadb-galera-0
3. Дождаться, пока Pod снова станет Ready
4. Проверить состояние MariaDB Galera после восстановления
5. Сохранить evidence
```markdown
# G6: Pod deletion and recovery

This scenatio validated controlled deletion and recovery of  on MariaDB galera Pod. 

| Run | Old Pod UID changed | Pod became Ready | Galera cluster size after recovery | Galera state after recovery | Result |
|----:|---------------------|------------------|-----------------------------------:|-----------------------------|--------|
| 1   | Yes                 | Yes              | 3                                  | Synced                      | Passed |
| 2   | Yes                 | Yes              | 3                                  | Synced                      | Passed |
| 3   | Yes                 | Yes              | 3                                  | Synced                      | Passed |

## Evidence files

- `evidence/g6-pod-delete-recovery-run-1.txt`
- `evidence/g6-pod-delete-recovery-run-2.txt`
- `evidence/g6-pod-delete-recovery-run-3.txt`
- `evidence/g6-pod-delete-recovery-excluded-calico-error.txt`

## Excluded attempt

An initial G6 attempt was excluded from validation because Pod deletion was
blocked by a Calico CNI authorization error during network sandbox cleanup.
After restarting the Calico DaemonSet, the cluster returned to a healthy state
and the scenario was repeated successfully.