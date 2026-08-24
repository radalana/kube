terminal-shell-container v3.1

non-interactive shell → MATCH
interactive shell     → MATCH

Conclusion:
current mapping does not reproduce Falco's TTY distinction.


#falco-ref-sensitive-read-untrusted

Positive:
cat /etc/shadow
→ MATCH

Negative:
cat /etc/hostname
→ NO MATCH

regular file → stdin
             ↓
MATCH



| Policy                     | Что установили                                                    | Что делать в v3.2                                 |
| -------------------------- | ----------------------------------------------------------------- | ------------------------------------------------- |
| `terminal-shell-container` | interactive и non-interactive shell оба match                     | оставить `partial`, не заявлять TTY-equivalence   |
| `sensitive-read-untrusted` | `/etc/shadow` match, `/etc/hostname` no match                     | сохранить; отдельно учесть host SSH/PAM noise     |
| `k8s-api-contact`          | Kubernetes API и `example.com:443` оба match                      | `partial`, mapping сейчас слишком широкий         |
| `ptrace-attach`            | `load_error` из-за 5 selector values; split работает              | технически исправить                              |
| `directory-traversal-read` | два `SubString` на одном path не загружаются; один `../` работает | сделать документированный `partial` approximation |
| `stdio-network-redirect`   | очень шумная на `dup/dup2/dup3`                                   | ещё нужно решить перед freeze                     |
