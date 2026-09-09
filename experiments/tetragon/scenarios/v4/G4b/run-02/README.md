08:35:21.950Z – 08:35:59.878Z
G4b Run 02: 1 scenario-related terminal-shell-container + 15 unrelated occurrences.

in interactive-validation.txt proves that interactive shell PTY has pts/0


sequence:
08:35:33.146  terminal-shell-container
08:35:33.148  /usr/bin/sh
              Pod = mariadb-galera-0

08:35:40.555  /usr/bin/id
08:35:42.779  /usr/bin/hostname
08:35:45.499  /usr/bin/ps
08:35:49.325  /usr/bin/sh exits

runc перед shell содержит --console-socket .../pty3008215576/pty.sock

| Policy                     | Raw records | Occurrences | Classification                       |
| -------------------------- | ----------: | ----------: | ------------------------------------ |
| `terminal-shell-container` |           1 |       **1** | **scenario-related**                 | grount truth from interactive-validation.tx that shell tty = pts/o
| `private-key-search`       |          15 |      **15** | unrelated  (on master, again ambient and outside window)                          |
| **Total**                  |      **16** |      **16** | **1 scenario-related, 15 unrelated** |
