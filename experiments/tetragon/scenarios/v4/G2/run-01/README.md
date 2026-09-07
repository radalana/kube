What was detected
| Node                           | Policy                     | Raw records | Candidate groups | detections
| ------------------------------ | -------------------------- | ----------: | ---------------: |
| master                         | `private-key-search`       |           2 |                2 | 2  -> deteciton
| worker2                        | `sensitive-read-untrusted` |          20 |                1 | 1   -> 1 detectuon
| **worker1, где выполнялся G2** | **none**                   |      *0 |            0|

insgesamt 3 deteciton not to g2


 `private-key-search` time in 13:11:58.756 13:11:58.930 before g2 run in 13:12:00.453

sensitive-read-untrusted:
 same PID
same exec_id
binary = /usr/lib/openssh/sshd-session
function = security_file_permission
targets:и targets:

/etc/pam.d/sshd
/etc/pam.d/common-auth
/etc/pam.d/common-account
/etc/pam.d/common-session
/etc/pam.d/common-password
/etc/pam.d/other -> SSH/PAM ambient pattern: pattern from ambient