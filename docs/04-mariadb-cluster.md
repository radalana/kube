# MariaDB Galera cluster

## Prerequisites

Complete the following steps first:

- `02-microk8s-cluster.md`
- `03-local-kubectl.md`
- `04-cluster-smoke-tests.md`

The cluster must have working DNS and dynamic PersistentVolume provisioning.

## Create the database and operator namespace
k apply -f cluster\namespaces\database.yaml
k apply -f cluster\namespaces\operator.yaml
## Add the MariaDB Operator Helm repository
helm repo add mariadb-operator https://helm.mariadb.com/mariadb-operator
helm repo update
## Install MariaDB Operator CRDs
```bash
helm upgrade --install mariadb-operator-crds `               
>>   oci://ghcr.io/mariadb-operator/charts/mariadb-operator-crds `
>>   --version 26.6.0 `
>>   --namespace operator
#check
k get crds | Select-String "mariadb"
```

## Install MariaDB Operator
Install MariaDB Operator in the database namespace and configure it to watch only resources in this namespace.
```bash
helm upgrade --install mariadb-operator `
  oci://ghcr.io/mariadb-operator/charts/mariadb-operator `
  --namespace database `
  --version 26.6.0 `
  --set currentNamespaceOnly=true `
  --wait `
  --timeout 5m
```   
## Verify the Operator
1. helm list -A | findstr /I mariadb
expected:
mariadb-operator         database
mariadb-operator-crds    operator
2. helm get values mariadb-operator `
  --namespace database `
  --all |
  Select-String "currentNamespaceOnly"
expected:
currentNamespaceOnly: true
3. check pods:
k get pods -n database

expected: 
mariadb-operator-b6548b959-tqq6t   1/1     Running   0          5m17s (only one pod)
## Create the root password Secret

## Deploy the MariaDB Galera cluster

## Verify MariaDB resources

## Test the database connection

## Cleanup