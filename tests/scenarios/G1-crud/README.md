# G1: CRUD through `appuser`

## Purpose

Simulate normal application access to MariaDB by performing authorized CRUD operations.

## Actions

1. Connect to MariaDB through the Kubernetes Service.
2. Authenticate as `appuser`.
3. Insert a test record.
4. Read the test record.
5. Update the test record.
6. Delete the test record.
7. Verify that the record was deleted.

## Authorized actor

MariaDB user: `appuser`

## Target

* Namespace: `database`
* Database: `appdb`
* Service: `mariadb-galera.database.svc.cluster.local`
* Port: `3306`

## Expected result

All SQL operations succeed, and the Kubernetes Job finishes with the status `Complete`.

The Job logs should confirm:

* authentication as `appuser`;
* connection to `appdb`;
* successful `INSERT`;
* successful `SELECT`;
* successful `UPDATE`;
* successful `DELETE`;
* `remaining_rows` equals `0`.

## Evidence

* Kubernetes Job status
* Kubernetes Pod status
* Job logs
* SQL query results
* MariaDB connection through the Kubernetes Service
* TLS version and cipher

## Run the scenario

Run the following commands from the repository root.

### Create the Job

```powershell
k apply -f .\tests\scenarios\G1-crud\g1-crud.yaml
```

### Wait for completion

```powershell
k wait --for=condition=complete job/g1-crud `
  -n database `
  --timeout=120s
```

### View the Job logs

```powershell
k logs -n database job/g1-crud
```

### Verify the Job and Pod

```powershell
k get job -n database -l scenario=g1-crud
k get pods -n database -l scenario=g1-crud
```

## Clean up

Delete the completed Job before the next execution:

```powershell
k delete -f .\tests\scenarios\G1-crud\g1-crud.yaml
```

## Validation

Execute the scenario at least three times without a security tool installed.

| Run | Job status | Expected SQL results | Result |
| --- | ---------- | -------------------- | ------ |
| 1   | Complete   | Confirmed            | Passed |
| 2   | Complete   | Confirmed            | Passed |
| 3   | Complete   | Confirmed            | Passed |


%Зачем повторять

Один успешный запуск показывает лишь, что сценарий сработал один раз.

Три запуска проверяют, что:

Job стабильно подключается к MariaDB;
данные прошлого запуска не мешают следующему;
INSERT, UPDATE и DELETE каждый раз работают одинаково;
сценарий воспроизводим;
результат не был случайным.

Это важно перед установкой security tools. Позже один и тот же G1 будет запускаться с Falco, Tetragon и Tracee. Сценарий должен работать одинаково при каждом инструменте.