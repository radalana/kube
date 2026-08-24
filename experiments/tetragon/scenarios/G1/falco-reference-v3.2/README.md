G1 – CRUD workload, final Tetragon v3.2

All three runs completed successfully. The CRUD workload authenticated as appuser, used database appdb, and successfully executed INSERT, UPDATE, and DELETE operations.

In all three runs, two Tetragon policies produced scenario-related policy matches:

falco-ref-run-shell-untrusted
falco-ref-stdio-network-redirect

falco-ref-run-shell-untrusted was triggered because the G1 Job executed its workload through a non-interactive /usr/bin/sh -c "...". No interactive terminal was opened.

falco-ref-stdio-network-redirect matched dup2/dup3 operations involving standard file descriptors during container and shell startup. Because this Tetragon mapping is broader than the corresponding Falco condition and does not establish that the source file descriptor was a network socket, the match is treated as a mapping limitation rather than evidence of actual network redirection.

Scenario attribution was confirmed using the scenario time window, node, Pod/container identity, matching runc container ID, PID/process correlation, and process arguments.

The multiple raw process_kprobe records are not interpreted as separate alerts or separate operations.

Run	run-shell-untrusted	stdio-network-redirect
run-01	observed	observed
run-02	observed	observed
run-03	observed	observed