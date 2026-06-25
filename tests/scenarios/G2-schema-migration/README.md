# G2: Schema migration through `migrationuser`

## Purpose

Simulate an authorized database schema migration performed during an application deployment.

The scenario changes the structure of a temporary table in `appdb` through the dedicated MariaDB user `migrationuser`.

## Actions

1. Connect to MariaDB through the Kubernetes Service.
2. Authenticate as `migrationuser`.
3. Remove a table left by an interrupted previous run.
4. Create the temporary table `g2_migration_test`.
5. Add the column `created_at` with `ALTER TABLE`.
6. Verify that the column exists.
7. Create the index `idx_g2_name`.
8. Verify that the index exists.
9. Drop the index.
10. Verify that the index no longer exists.
11. Display the resulting table structure.
12. Remove the temporary table.

## Authorized actor

MariaDB user: `migrationuser`

## Target

* Namespace: `database`
* Database: `appdb`
* Service: `mariadb-galera.database.svc.cluster.local`
* Port: `3306`
* Temporary table: `g2_migration_test`

## Security relevance

Schema migrations are legitimate deployment operations, but they use elevated database privileges and modify database structures.

The scenario produces activity related to:

* execution of a MariaDB client process;
* network connection to MariaDB;
* execution of a shell script inside a Kubernetes Job;
* database metadata changes;
* creation and deletion of database objects;
* increased file activity inside the MariaDB container.

The runtime security tools are not expected to understand the semantic meaning of each SQL statement without additional database instrumentation.

## Expected result

The Kubernetes Job finishes with status `Complete`.

The Job logs confirm:

* authentication as `migrationuser`;
* connection to `appdb`;
* successful `CREATE TABLE`;
* successful `ALTER TABLE`;
* `added_column_count` equals `1`;
* successful `CREATE INDEX`;
* `created_index_count` equals `1`;
* successful `DROP INDEX`;
* `remaining_index_count` equals `0`;
* successful final cleanup.

## Evidence

* Kubernetes Job status
* Kubernetes Pod status
* Job logs
* SQL query results
* MariaDB connection through the Kubernetes Service
* generated table definition from `SHOW CREATE TABLE`

## Run the scenario

Run the following commands from the repository root.

### Create the Job

```powershell
k apply -f .\tests\scenarios\G2-schema-migration\g2-schema-migration.yaml
```

### Wait for completion

```powershell
k wait --for=condition=complete job/g2-schema-migration `
  -n database `
  --timeout=120s
```

### View the Job logs

```powershell
k logs -n database job/g2-schema-migration
```

### Verify the Job and Pod

```powershell
k get job -n database -l scenario=g2-schema-migration
k get pods -n database -l scenario=g2-schema-migration
```

## Save validation evidence

Create the evidence directory:

```powershell
mkdir .\tests\scenarios\G2-schema-migration\evidence
```

Save the Job logs:

```powershell
k logs -n database job/g2-schema-migration `
  > .\tests\scenarios\G2-schema-migration\evidence\validation-run-1.txt
```

Change the filename to `validation-run-2.txt` and `validation-run-3.txt` for the following runs.

## Clean up

Delete the completed Job before the next execution:

```powershell
k delete job g2-schema-migration -n database
```

The scenario itself removes the temporary database table and index.

## Validation

The scenario is validated without a runtime security tool installed.

| Run | Job status | Column count | Created index count | Remaining index count | Result |
| --- | ---------- | -----------: | ------------------: | --------------------: | ------ |
| 1   | Complete   |            1 |                   1 |                     0 | Passed |
| 2   | Complete   |            1 |                   1 |                     0 | Passed |
| 3   | Complete   |            1 |                   1 |                     0 | Passed |
