07:44:46.384Z – 07:44:50Z

| Node    | First event  | Last event   |
| ------- | ------------ | ------------ |
| master  | 07:44:36.006 | 07:44:54.808 |
| worker1 | 07:44:39.218 | 07:44:55.141 |
| worker2 | 07:44:40.944 | 07:44:55.431 |

on worker1

===========
3 raw policy events = 3 detection all falco-ref-private-key-search:
| Time         | Node    | Activity                                    | Classification       |
| ------------ | ------- | ------------------------------------------- | -------------------- |
| 07:44:46.750 | worker1 | G3 validation `grep` of `/backup/appdb.sql` | **scenario-related** |
| 07:44:48.933 | master  | `apiservice-kicker → grep active`           | unrelated            |
| 07:44:49.101 | master  | `apiservice-kicker → grep active`           | unrelated            |


same as run02