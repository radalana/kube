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