2026-09-09T21:52:11.616Z
–
2026-09-09T21:52:56.714Z


ALL

| Policy                     | Raw records | Reconstructed occurrences | related  unrelated
| -------------------------- | ----------: | ------------------------: |
| `terminal-shell-container` |          10 |                    **10** |10         0
| `private-key-search`       |          27 |                    **27** |18         9
| `sensitive-read-untrusted` |          60 |                     **3** |
| `k8s-api-contact`          |           2 |                     **2** |2          0
| `directory-traversal-read` |           1 |                     **1** |
| **Total**                  |     **100** |                    **43** |

## terminal-shell-container 
raw 10 = 10 occ = 10 related
g4a 1
g5a 1
g5c 1
g6  6 look g6 = 2 for pre/post check + 4 for SST joiner + sst donor

## private-key-search

raw 27 = 27 occurence = 18 unre + 9 rel

#### 18 unrelated
on master apriservuice-kicker -> grep acriv (ambient)
#### 9 related
g3 1 -> validation insid backup /usr/bin/grep -cE "^(CREATE TABLE|INSERT INTO|CREATE.*VIEW)"
g6 8 -> after pods deletion sst scrip runn grep, all belongs to wsrep_sst_mariabackup
    on mariadb-galera-0 (joiner): 6 times 
    on mariadb-galera-1 (donor): 2 times

## k8s-api-contact 2 
2 raw = 2 occ = 2 related

g6:  both during new pod recovery
    G6 Pod deletion
    ↓
    new Pod
    ↓
    operator init / agent
    ↓
    Kubernetes API contact

## directory-traversal-read 1 worker 1
/sys/dev/block/8:1/../queue/physical_block_size

g6: after deleteion


## sensitive-read-untrusted
60 raw = 3 occ = 3 unrelated

worker 1 -> 2 times
 worker 2 -> 2 times

 all sshd pam ambient pattern


| Policy                     | Scenario-related | Unrelated | Main attribution                  |
| -------------------------- | ---------------: | --------: | --------------------------------- |
| `terminal-shell-container` |           **10** |         0 | G4a, G5a, G5c, G6, final G7 check |
| `private-key-search`       |            **9** |        18 | G3 validation + G6 SST            |
| `k8s-api-contact`          |            **2** |         0 | G6 recreated Pod                  |
| `directory-traversal-read` |            **1** |         0 | G6 recreated Pod startup          |
| `sensitive-read-untrusted` |                0 |     **3** | ambient SSH/PAM                   |
| **Total**                  |           **22** |    **21** |                                   |
