# G4: Authorized `kubectl exec`

This scenario simulates authorized administrative access to an existing MariaDB container.

It contains two variants:

* G4a executes predefined commands without an interactive terminal.
* G4b opens an interactive shell with an attached TTY.

## Target

* Namespace: `database`
* Pod: `mariadb-galera-0`
* Container: `mariadb`

---

## G4a: Non-interactive exec

### Purpose

Execute predefined diagnostic commands inside the MariaDB container without opening an interactive terminal.

The command starts a temporary `sh` process, executes the predefined commands and terminates automatically.

### Commands executed

The script executes:

```sh
id
hostname
ps
```

Expected behavior:

* `id` displays the Linux user inside the container;
* `hostname` displays `mariadb-galera-0`;
* `ps` displays the active processes;
* the `TTY` column displays `?`, meaning no terminal is attached;
* the script exits with code `0`.

### Run the scenario

Run the script from the repository root:

```powershell
.\tests\scenarios\G4-kubectl-exec\run-g4a-non-interactive.ps1
```

Run the script three times.

No cleanup is required because `kubectl exec` does not create a Kubernetes resource. The temporary `sh` and `ps` processes terminate after each execution.

### Expected result

The output should contain:

```text
uid=999(mysql) gid=999(mysql) groups=999(mysql)
mariadb-galera-0
PID TTY TIME CMD
```

The exact process IDs and process times may differ between runs.

The `TTY` value for `sh` and `ps` should be:

```text
?
```

The script should finish with:

```text
G4a completed successfully
```

### G4a validation

| Run | Exit code | Hostname confirmed | No TTY confirmed | Result |
| --- | --------: | ------------------ | ---------------- | ------ |
| 1   |         0 | Yes                | Yes              | Passed |
| 2   |         0 | Yes                | Yes              | Passed |
| 3   |         0 | Yes                | Yes              | Passed |

---

## G4b: Interactive shell

### Purpose

Open an authorized interactive shell inside the MariaDB container.

The `-i` option keeps standard input open, and the `-t` option creates a pseudo-terminal. This distinguishes G4b from the non-interactive G4a scenario.

### Run the scenario

Run the script from the repository root:

```powershell
.\tests\scenarios\G4-kubectl-exec\run-g4b-interactive.ps1
```

After the shell prompt appears, enter the following commands manually:

```sh
id
hostname
ps
exit
```

Run the scenario three times.

No cleanup is required. The interactive shell terminates after `exit`.

### Expected result

The output should confirm:

* the shell runs as Linux user `mysql`;
* the hostname is `mariadb-galera-0`;
* the `TTY` column contains a pseudo-terminal such as `pts/0` or `pts/1`;
* all diagnostic commands complete successfully;
* the script returns to PowerShell after `exit`;
* the script prints `G4b completed successfully`.

Example:

```text
PID TTY          TIME CMD
782 pts/0    00:00:00 sh
790 pts/0    00:00:00 ps
```

The exact process IDs and `pts` number may differ between runs.

### G4b validation

| Run | Interactive shell opened | TTY observed | Commands completed | Result |
| --- | ------------------------ | ------------ | ------------------ | ------ |
| 1   | Yes                      | `pts/0`      | Yes                | Passed |
| 2   | Yes                      | `pts/1`      | Yes                | Passed |
| 3   | Yes                      | `pts/...`    | Yes                | Passed |

## Validation note

An initial G4b attempt was excluded because an invalid character was entered before the `ps` command. The shell returned exit code `127`. This was a manual input error and not a failure of the scenario.
