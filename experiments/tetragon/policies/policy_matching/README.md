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


Before
| Policy                     | Что установили                                                    | Что делать в v3.2                                 |
| -------------------------- | ----------------------------------------------------------------- | ------------------------------------------------- |
| `terminal-shell-container` | interactive и non-interactive shell оба match                     | оставить `partial`, не заявлять TTY-equivalence   |
| `sensitive-read-untrusted` | `/etc/shadow` match, `/etc/hostname` no match                     | сохранить; отдельно учесть host SSH/PAM noise     |
| `k8s-api-contact`          | Kubernetes API и `example.com:443` оба match                      | `partial`, mapping сейчас слишком широкий         |
| `ptrace-attach`            | `load_error` из-за 5 selector values; split работает              | технически исправить                              |
| `directory-traversal-read` | два `SubString` на одном path не загружаются; один `../` работает | сделать документированный `partial` approximation |
| `stdio-network-redirect`   | очень шумная на `dup/dup2/dup3`                                   | ещё нужно решить перед freeze                     |


Now
# Tetragon Falco-Reference Policy Harmonization v4

This directory contains the policy audit and candidate mappings used to
improve the Tetragon configuration derived from the Falco reference ruleset.

The v3.2 mappings are reviewed using the following decisions:

- KEEP: retain the existing mapping.
- MODIFY: retain the detection purpose but change the Tetragon implementation.
- REPLACE: replace the existing mapping with a more suitable Tetragon mechanism.
- PARTIAL: the Falco semantics cannot be reproduced completely and the remaining
  difference is documented.

## Current policy audit

| Policy | v3.2 observation | v4 decision | Current status |
|---|---|---|---|
| `run-shell-untrusted` | The v3.2 mapping matched ordinary shell execution and was broader than the Falco rule. | MODIFY / partial | First candidate using `security_bprm_check + matchParentBinaries` was rejected. Second candidate using `sys_execve + matchBinaries` passed negative and positive validation and is the accepted v4 candidate. |
| `terminal-shell-container` | Interactive and non-interactive container shells can both match. Falco additionally evaluates `proc.tty != 0`. | KEEP / partial | No TTY-specific replacement is introduced. `tty_open` / `pty_open` would observe TTY-related events but would not reproduce the same process-state semantics as Falco. |
| `sensitive-read-untrusted` | `/etc/shadow` matched while `/etc/hostname` did not. Host SSH/PAM activity can create background matches. | KEEP | Existing mapping retained. Background host activity must be separated during attribution. |
| `k8s-api-contact` | Kubernetes API traffic and unrelated HTTPS destinations can both match. | REVIEW / partial | Current mapping is broader than the Falco reference condition and still requires review. |
| `ptrace-attach` | The original selector containing five values caused a policy load error. Splitting the values into valid selectors worked. | KEEP corrected version | Technical selector issue fixed. |
| `directory-traversal-read` | Multiple `SubString` values on the same path selector did not load. A single `../` condition worked. | KEEP / partial | Retained as a documented approximation. |
| `stdio-network-redirect` | The v3.2 mapping matched `dup/dup2/dup3` without verifying that the source descriptor represented a network socket. | MODIFY / partial | New candidate uses `do_dup2`, `type: file`, `FileType: socket`, destination fd `0/1/2`, and container approximation. Validation: pipe → stdin = no match; IPv4 TCP socket → stdin = match; Unix socket → stdin = match. The mapping is improved but remains partial because `FileType: socket` does not distinguish IPv4/IPv6 from Unix sockets. |

## Validation principle

Candidate policies are validated independently before inclusion in the final
v4 bundle. Where a closer mapping would require kernel-specific hooks that
change the meaning of the Falco condition, the mapping is kept partial rather
than forcing an artificial one-to-one implementation.

## Next policies to review

- `memfd-exec-stage`
- `kernel-module`
- `exec-dev-shm`
- `private-key-search`
- `aws-credential-search`
- `k8s-api-contact`
- `ssh-nonstandard-port`

The final v4 bundle will be frozen only after the policy audit is complete.
Afterwards, the final ambient baseline and scenarios G1 and G2 will be repeated
under the same frozen v4 configuration before continuing with G3-G7.