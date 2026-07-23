# G5: File and Process Inspection

## Purpose

G5 represents authorized diagnostic inspection inside the MariaDB container.
The scenario includes reading selected configuration files and process-related
files. It is used to check normal administrative activity that can also look
suspicious for runtime security tools.

The scenario does not modify the container. It only reads existing files and
metadata.

## Discovery

The script `run-g5-discovery.ps1` performs a file discovery inside the MariaDB
container before the final G5 scenario commands are defined. It searches for
configuration files, log files, and selected files under `/proc`.

Run the discovery script with:

```powershell
.\tests\scenarios\G5-file-process-inspection\run-g5-discovery.ps1 `
  *> .\tests\scenarios\G5-file-process-inspection\evidence\g5-discovery.txt
```

The result is stored in:

```text
tests/scenarios/G5-file-process-inspection/evidence/g5-discovery.txt
```

## Discovery Result

The following files were selected based on the discovery output.

### Configuration files

- `/etc/mysql/mariadb.cnf`
- `/etc/mysql/mariadb.conf.d/0-galera.cnf`

### Log files

No MariaDB-specific log file was found under `/var/log`. Therefore, log-file
reading was not included in the final G5 file-inspection scenario.

### Process-related files

- `/proc/1/cmdline`
- `/proc/1/status`
- `/proc/self/status`
- `/proc/meminfo`

## G5a: Configuration File Read

G5a reads selected MariaDB configuration files inside the running MariaDB
container.

The script is stored in:

```text
tests/scenarios/G5-file-process-inspection/run-g5a-config-read.ps1
```

Run G5a with:

```powershell
.\tests\scenarios\G5-file-process-inspection\run-g5a-config-read.ps1 `
  *> .\tests\scenarios\G5-file-process-inspection\evidence\g5a-config-read-run-1.txt
```

For the second and third validation run, use:

```powershell
.\tests\scenarios\G5-file-process-inspection\run-g5a-config-read.ps1 `
  *> .\tests\scenarios\G5-file-process-inspection\evidence\g5a-config-read-run-2.txt
```

```powershell
.\tests\scenarios\G5-file-process-inspection\run-g5a-config-read.ps1 `
  *> .\tests\scenarios\G5-file-process-inspection\evidence\g5a-config-read-run-3.txt
```

During G5a, selected MariaDB configuration files are read inside the container.
Sensitive values, such as authentication strings, are redacted before the
validation output is stored as evidence.

### G5a Expected Result

A successful G5a run should show:

- the target hostname `mariadb-galera-0`;
- file metadata for `/etc/mysql/mariadb.cnf`;
- file metadata for `/etc/mysql/mariadb.conf.d/0-galera.cnf`;
- readable configuration content;
- redacted sensitive authentication values;
- the final message `G5a config read completed successfully`.

### G5a Validation

| Run | Exit code | Expected output                               | Result |
|-----|----------:|-----------------------------------------------|--------|
| 1   | 0         | Selected MariaDB configuration files readable | Passed |
| 2   | 0         | Selected MariaDB configuration files readable | Passed |
| 3   | 0         | Selected MariaDB configuration files readable | Passed |

### Evidence Files

- `evidence/g5-discovery.txt`
- `evidence/g5a-config-read-run-1.txt`
- `evidence/g5a-config-read-run-2.txt`
- `evidence/g5a-config-read-run-3.txt`

### Notes

Sensitive authentication values found in the configuration output are not stored
in plain text. They are replaced with redacted placeholders before the evidence
is committed.

## G5b: skipped because no MariaDB log file was found
## G5c: Process Information Read

G5c reads selected `/proc` files inside the running MariaDB container. These
files provide process-related information about the main MariaDB process and the
current shell process used by `kubectl exec`.

The script is stored in:

```text
tests/scenarios/G5-file-process-inspection/run-g5c-proc-read.ps1
```

Run G5c with:

```powershell
.\tests\scenarios\G5-file-process-inspection\run-g5c-proc-read.ps1 `
  *> .\tests\scenarios\G5-file-process-inspection\evidence\g5c-proc-read-run-1.txt
```

For the second and third validation run, use:

```powershell
.\tests\scenarios\G5-file-process-inspection\run-g5c-proc-read.ps1 `
  *> .\tests\scenarios\G5-file-process-inspection\evidence\g5c-proc-read-run-2.txt
```

```powershell
.\tests\scenarios\G5-file-process-inspection\run-g5c-proc-read.ps1 `
  *> .\tests\scenarios\G5-file-process-inspection\evidence\g5c-proc-read-run-3.txt
```

## G5c Expected Result

A successful G5c run should show:

- the target hostname `mariadb-galera-0`;
- the main container process from `/proc/1/cmdline`;
- readable process information from `/proc/1/status`;
- readable process information from `/proc/self/status`;
- readable memory information from `/proc/meminfo`;
- the final message `G5c proc read completed successfully`.

In the validation output, `/proc/1/cmdline` showed `mariadbd`, which confirms
that the main process inside the MariaDB container is the MariaDB server
process.

## G5c Validation

| Run | Exit code | Expected output | Result |
|---|---:|---|---|
| 1 | 0 | Selected `/proc` files readable | Passed |
| 2 | 0 | Selected `/proc` files readable | Passed |
| 3 | 0 | Selected `/proc` files readable | Passed |

