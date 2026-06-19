# MariaDB Galera cluster

## Prerequisites

Complete the following steps first:

- `02-microk8s-cluster.md`
- `03-local-kubectl.md`
- `04-cluster-smoke-tests.md`

The cluster must have working DNS and dynamic PersistentVolume provisioning.

## Create the database namespace
k apply -f cluster\namespaces\database.yaml
## Add the MariaDB Operator Helm repository
helm repo add mariadb-operator https://helm.mariadb.com/mariadb-operator
## Install MariaDB Operator CRDs

## Install MariaDB Operator

## Verify the Operator

## Create the root password Secret

## Deploy the MariaDB Galera cluster

## Verify MariaDB resources

## Test the database connection

## Cleanup