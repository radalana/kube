START  2026-09-09T 11:01: 55.744Z
END    2026-09-09T 11:02: 05.395Z
EXIT   0


| Node    | First event   | Last event    |
| ------- | ------------- | ------------- |
| master  | 11:01:37.819Z | 11:02:08.711Z | -> in window  - 4 × private-key-search
| worker1 | 11:01:42.622Z | 11:02:09.125Z | -> in window     20 raw sensitive-read-untrusted records → 1 SSH/PAM occurrence
| worker2 | 11:01:44.297Z | 11:02:09.473Z | -> in window


worjer1;
1 occurence scenario related: 

11:02:00.860Z
falco-ref-terminal-shell-container
target = /usr/bin/sh

after:
11:02:00.863Z
/usr/bin/sh -c ...
Pod = mariadb-galera-0  тоже не сам reading а bin/bash


SSH/PAM occurrence  ~11:01:57.833Z ambietn unrelated
G5a shell            11:02:00.860Z ambient related

| Result                               | Count |
| ------------------------------------ | ----: |
| Scenario-related                     | **1** |
| Unrelated `private-key-search`       |     4 |
| Unrelated `sensitive-read-untrusted` |     1 |
| **Total unrelated**                  | **5** |
| **Total occurrences**                | **6** |
