# MariaDB backup user

## Purpose

for G3 scenario

## Create the password Secret

k apply -f .\cluster\mariadb\cluster\secrets\backup-password.secret.yaml

## Create backupuser

k apply -f .\cluster\mariadb\cluster\users\backup-user.yaml  

## Grant backup privileges

k apply -f .\cluster\mariadb\cluster\grants\backup-user-grant.yaml 

previleges:

- SELECT
- SHOW VIEW
- TRIGGER

## Verify the user and privileges

Check resources User и Grant.
k get user,grant -n database 

Check preveliges in maridb SHOW GRANTS.
 'SHOW GRANTS FOR `backupuser`@`%`;' |         
k exec -i -n database mariadb-galera-0 -c mariadb -- `
sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"'

## Next step

The backup user is used by the G3 backup scenario documented under:

tests/scenarios/G3-backup/