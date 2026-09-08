07:39:53.823Z – 07:39:57Z window

on worker1

| Time         | Node    | Context                           | Classification       |
| ------------ | ------- | --------------------------------- | -------------------- |
| 07:39:54.319 | worker1 | G3 `grep` of `/backup/appdb.sql`  | scenario-related |
| 07:39:55.581 | master  | `apiservice-kicker → grep active` | unrelated    exec_id = a        |
| 07:39:55.780 | master  | `apiservice-kicker → grep active` | unrelated     exec<-id = b      |

___________________

Same pattern as in run01 -> was caused not by mriadb but still in scenario : ->

07:39:54.147   /usr/bin/sh
        ↓
07:39:54.149   /usr/bin/mariadb-dump
        ↓
07:39:54.311   mariadb-dump exits
        ↓
wc
        ↓
sha256sum
        ↓
07:39:54.319   grep
               └─ falco-ref-private-key-search
        ↓
head

______________________

related proccess_exec shows grep -cE "^(CREATE TABLE|INSERT INTO|CREATE.*VIEW)" /backup/appdb.sql 

G3 produced a scenario-related detection, but the immediate trigger was the auxiliary grep validation of the completed dump, not mariadb-dump itself.
=========================

raw policy matches          3
detection occurrences       3

scenario-related            1
unrelated                   2