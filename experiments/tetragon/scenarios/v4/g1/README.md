| Run    | Raw policy records | Что сработало                                              |
| ------ | -----------------: | ---------------------------------------------------------- |
| Run 01 |                  4 | 4 × `private-key-search`                                   |
| Run 02 |                  4 | 4 × `private-key-search`                                   |
| Run 03 |                 44 | 4 × `private-key-search` + 40 × `sensitive-read-untrusted` |


G1 produced 0 scenario-related Tetragon detection occurrences in all three runs.


| Run | Policy matches in window                         | Detection occurrences | Scenario-related |
| --- | ------------------------------------------------ | --------------------: | ---------------: |
| 01  | `private-key-search`                             |                     4 |                0 |
| 02  | `private-key-search`                             |                     4 |                0 |
| 03  | `private-key-search`, `sensitive-read-untrusted` |                     6 |                0 |
