START  2026-09-09T20:22:15.595Z
END    2026-09-09T20:22:56.678Z
EXIT   0


in window
| Policy                     | Raw records | Reconstructed occurrences | related    unrelated
| -------------------------- | ----------: | ------------------------: |
| `sensitive-read-untrusted` |          60 |                         3 |0           3
| `private-key-search`       |          24 |                        24 |8           16
| `terminal-shell-container` |           6 |                         6 |6           0
| `k8s-api-contact`          |           2 |                         2 |2           0
| `directory-traversal-read` |           1 |                         1 |1
| **Total**                  |      **93** |                    **36** |
