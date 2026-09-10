G7_START_UTC=2026-09-09T22:06:37.496Z
G7_END_UTC=2026-09-09T22:07:24.891Z


| Policy                     | Raw records | Occurrences |
| -------------------------- | ----------: | ----------: |
| `terminal-shell-container` |          10 |      **10** | same run-01 o2
| `private-key-search`       |          27 |      **27** | same run 01
| `sensitive-read-untrusted` |          80 |       **4** | unrelated 4
| `k8s-api-contact`          |           2 |       **2** |
| `directory-traversal-read` |           1 |       **1** |
| **Total**                  |     **120** |      **44** |


sensetive-read :
all sshd to pam
master  → 20 raw
master  → 20 raw
worker1 → 20 raw
worker2 → 20 raw

| Policy                     | Scenario-related | Unrelated |
| -------------------------- | ---------------: | --------: |
| `terminal-shell-container` |           **10** |         0 | same
| `private-key-search`       |            **9** |        18 | 
| `k8s-api-contact`          |            **2** |         0 | same
| `directory-traversal-read` |            **1** |         0 | same
| `sensitive-read-untrusted` |                0 |     **4** | same
| **Total**                  |           **22** |    **22** |
