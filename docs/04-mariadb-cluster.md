# MariaDB Galera cluster

## Prerequisites

Complete the following steps first:

- `01-microk8s-cluster.md`
- `02-local-kubectl.md`
- `03-cluster-smoke-tests.md`

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
mariadb-operator-b6548b959-tqq6t   1/1     Running   0          5m17s
# Secrets configuration
## Create the root password Secret
1. On master node check if is encryption on rest in enabled
sudo grep -- '--encryption-provider-config' \
  /var/snap/microk8s/current/args/kube-apiserver

if nothing -> encryption is disabled

### 2. Create backup on the master node

a. mkdir -p "$HOME/microk8s-backups"
chmod 700 "$HOME/microk8s-backups"

b. microk8s dbctl backup \
  -o "$HOME/microk8s-backups/dqlite-before-encryption-$(date +%F-%H%M%S).tar.gz"

c. check backup
ls -lh "$HOME/microk8s-backups"

d. create checksum
sha256sum "$HOME"/microk8s-backups/dqlite-before-encryption-*.tar.gz

e. set rights
chmod 600 "$HOME"/microk8s-backups/dqlite-before-encryption-*.tar.gz

f. save locally if master node is unavailable: 
scp sveta@master:/home/sveta/microk8s-backups/dqlite-before-encryption-*.tar.gz .

g. add in backup in .gitignore

 ### 3. Create config encryption file (inside master)

a. create encryption key:
ENCRYPTION_KEY="$(openssl rand -base64 32)"

b. create config file:  

sudo tee /var/snap/microk8s/current/args/encryption-config.yaml > /dev/null <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - secretbox:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

c. Delete key from env var 
unset ENCRYPTION_KEY

d. set rights only root can read this file:

    I. sudo chown root:root \
  /var/snap/microk8s/current/args/encryption-config.yaml
    II. sudo chmod 600 \
  /var/snap/microk8s/current/args/encryption-config.yaml
    III. check rights:
    sudo ls -l \
  /var/snap/microk8s/current/args/encryption-config.yaml
### 4. Add encryption config in api sevrer config 
a. backup api server config: 
sudo cp \
  /var/snap/microk8s/current/args/kube-apiserver \
  /var/snap/microk8s/current/args/kube-apiserver.bak-before-encryption

b. add encryption config in api server config:
FLAG='--encryption-provider-config=/var/snap/microk8s/current/args/encryption-config.yaml'

sudo grep -qxF -- "$FLAG" \
  /var/snap/microk8s/current/args/kube-apiserver \
  || printf '%s\n' "$FLAG" | sudo tee -a \
  /var/snap/microk8s/current/args/kube-apiserver > /dev/null

c. check:
 sudo grep -- '--encryption-provider-config' \
  /var/snap/microk8s/current/args/kube-apiserver

expected: --encryption-provider-config=/var/snap/microk8s/current/args/encryption-config.yaml

### 5. restart mikros8k
a. restart
sudo snap restart microk8s
b. wait 
microk8s status --wait-ready
c. check nodes
microk8s kubectl get nodes

### 6. check if new setting are applyed and encryption is before identity
sudo grep -nE 'secretbox:|identity:' \
  /var/snap/microk8s/current/args/encryption-config.yaml

expected: 8:      - secretbox:
13:      - identity: {}

### 7. test with test secret
a. create ns:
microk8s kubectl create namespace encryption-test
b. create secret:
microk8s kubectl create secret generic encryption-test \
  --namespace encryption-test \
  --from-literal=password='test-value'
c. read secret:
microk8s kubectl get secret encryption-test \
  --namespace encryption-test \
  -o jsonpath='{.data.password}' |
  base64 -d

echo

d. k delete ns encryption-test

## Check rights 
### i as user have rights to read secrets in database ns
a. k auth can-i get secrets -n database
b. k auth can-i list secrets -n database

### if mariadb operator can read secrets inside pod
k auth can-i get secret/mariadb-root-password `
   -n database `
  --as=system:serviceaccount:database:mariadb-operator

## Create root passwort for mariadb
k apply -f cluster\mariadb\cluster\secrets\mariadb-root-password.secret.yaml 

## Deploy the MariaDB Galera cluster
1. Check whether all three nodes are schedulable - Kuberentes Scheduler can place new pods in this node
kubectl get nodes `
  -o custom-columns="NAME:.metadata.name,TAINTS:.spec.taints"
2. k apply -f .\cluster\mariadb\cluster\mariadb-galera.yaml

## Verify MariaDB resources
1. Check created resources
kubectl get mariadb,statefulset,pods,svc,pvc `
  -n database `
  -o wide

  what should be:
  MariaDB resource has Ready=True,
  StetefulSet 3/3
  all pods are running
  all pvc has Bound,
  repicalces on different nodes

2. check Galera from one pod (here from mariadb-galera-0): 
k exec -n database mariadb-galera-0 -c mariadb -- sh -c `
  'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW STATUS WHERE Variable_name IN (''wsrep_cluster_size'',''wsrep_cluster_status'',''wsrep_ready'',''wsrep_local_state_comment'');"'

  expected:
  'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW STATUS WHERE Variable_name IN (''wsrep_cluster_size'',''wsrep_cluster_status'',''wsrep_ready'',''wsrep_local_state_comment'');"'
Variable_name   Value
wsrep_local_state_comment       Synced #this pode is syncornized with galera cluster
wsrep_cluster_size      3  #node(pod mariadb-galera0) can see all 3 members of galera node
wsrep_cluster_status    Primary # - has quorum (can vote)
wsrep_ready     ON # can accept queries

3. from all pods: 
0..2 | ForEach-Object {
  Write-Host "`n=== mariadb-galera-$_ ==="
   k exec -n database "mariadb-galera-$_" -c mariadb -- sh -c `
    'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW STATUS WHERE Variable_name IN (''wsrep_cluster_size'',''wsrep_cluster_status'',''wsrep_ready'',''wsrep_local_state_comment'');"'
 }
exoected:

wsrep_cluster_size      3
wsrep_cluster_status    Primary
wsrep_ready     ON

=== mariadb-galera-1 ===
Variable_name   Value
wsrep_local_state_comment       Synced
wsrep_cluster_size      3
wsrep_cluster_status    Primary
wsrep_ready     ON

=== mariadb-galera-2 ===
Variable_name   Value
wsrep_local_state_comment       Synced
wsrep_cluster_size      3
wsrep_cluster_status    Primary
wsrep_ready     ON


 *in my case error on mariadb-galera-1 Kubernetes API can not connect with tls with kubelet on  10.0.0.2 Node (master node)
 reaso: tls sertificate for public adress, i use for internal communication private adress - recreate kubelet.crt
# Test the database connection
## check with root : DNS, Service, network, root Secret and mariadb work together?
1. Check Service 
k get svc -n database mariadb-galera
ecpexted (port 3306):
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
mariadb-galera   ClusterIP   10.152.183.39   <none>        3306/TCP   22h

2. Service (mariadb-galera) has backend ip-adresses (where kubernetes servise sends connections?)
k get endpointslice -n database -l kubernetes.io/service-name=mariadb-galera -o wide
expected:
NAME                   ADDRESSTYPE   PORTS   ENDPOINTS                              AGE
mariadb-galera-f6z4b   IPv4          3306    10.1.235.144,10.1.189.76,10.1.219.71   22h

ip adress of all 3 endpoints

3.  Check DNS resolution and connectivity to MariaDB through the ClusterIP Service
k exec -n database mariadb-galera-0 -c mariadb -- sh -c `
  'mariadb --protocol=TCP -h mariadb-galera.database.svc.cluster.local -P 3306 -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SELECT VERSION() AS version; SELECT @@hostname AS connected_to; SHOW DATABASES;"'


## Create Database, User, Grant

## Check connection via not-root user
## Cleanup