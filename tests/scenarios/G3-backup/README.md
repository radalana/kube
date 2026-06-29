# G3: Authorized logical backup

## Purpose

Simulate an authorized logical backup of the MariaDB database `appdb`.

The scenario uses `mariadb-dump` to read the database through the Kubernetes Service and write the resulting SQL dump to temporary Pod storage.

## Authorized actor

MariaDB user: `backupuser`

## Prerequisites

The backup user, password Secret and required privileges must already exist as documented in:

```text
docs/05-mariadb-backup-user.md
```

Required resources:

* MariaDB user: `backupuser`
* Secret: `backup-password`
* Grant on `appdb.*`: `SELECT`, `SHOW VIEW`, `TRIGGER`

## Target

* Namespace: `database`
* Database: `appdb`
* Service: `mariadb-galera.database.svc.cluster.local`
* Port: `3306`
* Backup file inside the Pod: `/backup/appdb.sql`

## Actions

1. Connect to MariaDB through the Kubernetes Service.
2. Authenticate as `backupuser`.
3. Create a logical dump of `appdb`.
4. Store the dump in an `emptyDir` volume.
5. Verify that the dump file exists and is not empty.
6. Print the dump size.
7. Calculate a SHA-256 checksum.
8. Count selected SQL statements in the dump.
9. Print the first lines of the dump.

## Storage behavior

The backup is written to an `emptyDir` volume mounted at `/backup`.

The file exists only while the Job Pod exists. Deleting the Job and Pod also deletes the backup file.

This scenario validates backup activity. It does not provide persistent backup storage.

## Expected result

The Kubernetes Job finishes with status `Complete`.

The logs must contain:

* `Starting authorized logical backup`
* `Backup completed successfully`
* a backup size greater than `0`
* a SHA-256 checksum
* the MariaDB dump header
* `Database: appdb`

The exact file size and checksum are not fixed because they depend on the current database contents and generated dump.

## Run the scenario

Run the following commands from the repository root.

### Create the Job

```powershell
k apply -f .\tests\scenarios\G3-backup\g3-backup.yaml
```

### Wait for completion

```powershell
k wait --for=condition=complete job/g3-backup `
  -n database `
  --timeout=120s
```

### View the Job logs

```powershell
k logs -n database job/g3-backup
```

### Verify the Job and Pod

```powershell
k get job -n database -l scenario=g3-backup
k get pods -n database -l scenario=g3-backup
```

Expected statuses:

```text
Job: Complete
Pod: Completed
Restarts: 0
```

## Observed output: validation run 1

```text
Starting authorized logical backup
Backup completed successfully
Backup file: /backup/appdb.sql
Backup size in bytes:
2077
Backup checksum:
5c84c4e979e1363b0609241cc05e0af93ebda7a92ccdb3b022a76ef21e049140  /backup/appdb.sql
Database statements found in dump:
1
First lines of backup:
/*M!999999\- enable the sandbox mode */
-- MariaDB dump 10.19-11.8.8-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: mariadb-galera.database.svc.cluster.local    Database: appdb
-- ------------------------------------------------------
-- Server version       11.8.8-MariaDB-ubu2404
```

## Save validation evidence

Create the evidence directory:

```powershell
mkdir .\tests\scenarios\G3-backup\evidence
```

Save the logs:

```powershell
k logs -n database job/g3-backup `
  > .\tests\scenarios\G3-backup\evidence\validation-run-1.txt
```

Use `validation-run-2.txt` and `validation-run-3.txt` for the following runs.

## Clean up

Delete the completed Job before the next execution:

```powershell
k delete job g3-backup -n database
```

This also removes the Pod and its temporary `emptyDir` backup.

## Validation

The scenario is executed three times without a runtime security tool installed.

| Run | Job status | Backup size greater than 0 | Checksum generated | Result |
| --- | ---------- | -------------------------- | ------------------ | ------ |
| 1   | Complete   | Yes                        | Yes                | Passed |
| 2   | Complete   |               yes          |     yes            | Passed |
| 3   |     Com     | yes                       |     yes            |  Passed|
