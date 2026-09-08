RESULT:
raw policy matches             = 1
detection occurrences          = 1
scenario-related detections    = 1
unrelated detections           = 0

=========
Triger:
falco-ref-private-key-search
← G3 validation grep
=========


scenario was on worker1

Policy matches:

falco-ref-provate-key-search on worker1 

07:28:14.356z 07:28:14.643258 (policy match) - 07:28:18z -> in window
process = /usr/bin/sh
target = /usr/bin/grep
Pod = g3-backup-htwx7

связанный process_exec показывает
/usr/bin/grep
-cE "^(CREATE TABLE|INSERT INTO|CREATE.*VIEW)" /backup/appdb.sql

что происходил Grep и не apiservice-kicker → grep active, а то что g3 job проверял содержимое dump

07:28:14.586   /usr/bin/mariadb-dump
...
07:28:14.639   mariadb-dump exit
07:28:14.643   grep → private-key-search

Но это была не активность самой mariadb, а именно

mariadb делает logical backup

и после него сам Job еще дополнительно делает :
wc
sha256sum
grep
head
Поэтому я бы НЕ писала:
`The logical backup triggered private-key-search.`

