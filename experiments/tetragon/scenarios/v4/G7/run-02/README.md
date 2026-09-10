G7_START_UTC=2026-09-09T22:01:19.431Z
G7_END_UTC=2026-09-09T22:02:03.006Z


| Policy                     | Raw records | Reconstructed occurrences | related  unrelated
| -------------------------- | ----------: | ------------------------: |
| `terminal-shell-container` |          10 |                    **10** | 10         0
| `private-key-search`       |          25 |                    **25** |  9         16
| `sensitive-read-untrusted` |          40 |                     **2** |  0         2
| `k8s-api-contact`          |           2 |                     **2** | 2          0
| `directory-traversal-read` |           1 |                     **1** |  1         0
| **Total**                  |      **78** |                    **40** |


## terminal-shell-container
raw 10 = 10 occ = 10 related

g4a 1
g5a 1
g5c 1

g6  6 look g6 = 2 for pre/post check + 4 for SST joiner + sst donor
________________
same as in run-01

## private-key-search
raw 25 = 25 occur
##### 16 unrelated
apiservice kicker 

##### 9 related (same run-01)
g3 1: (same run-01) -> validation insid backup /usr/bin/grep -cE "^(CREATE TABLE|INSERT INTO|CREATE.*VIEW)"
g6 8 -> same run-01

## k8s-api-contact
2 raw = 2 occ
g6 2: beim pod recovery 1 from init container another form agent
    22:01:30.036
        mariadb-operator
        container = init
        tcp_connect
        10.152.183.1:443

    22:01:59.559
        mariadb-operator
        container = agent
        tcp_connect
        10.152.183.1:443

## directory-traversal-read
1 raw = 1 occ
g6: 1 /sys/dev/block/8:1/../queue/physical_block_size same as in run--01

## sensitive-read-untrusted
40 raw = 2 occ = 2 unrela


| Policy                     | Scenario-related | Unrelated |
| -------------------------- | ---------------: | --------: |
| `terminal-shell-container` |           **10** |         0 |
| `private-key-search`       |            **9** |        16 |
| `k8s-api-contact`          |            **2** |         0 |
| `directory-traversal-read` |            **1** |         0 |
| `sensitive-read-untrusted` |                0 |     **2** |
| **Total**                  |           **22** |    **18** |
G1
→ 0

G2
→ 0

G3
→ 1 private-key-search

G4a
→ 1 terminal-shell-container

G5a
→ 1 terminal-shell-container

G5c
→ 1 terminal-shell-container

G6
→ 17:
   6 terminal-shell-container
   8 private-key-search
   2 k8s-api-contact
   1 directory-traversal-read

G7 final validation
→ 1 terminal-shell-container