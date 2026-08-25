|                              | Run-01           | Run-02           |
| ---------------------------- | ---------------- | ---------------- |
| `run-shell-untrusted`        | scenario-related | scenario-related |
| `stdio-network-redirect`     | scenario-related | scenario-related |
| Scenario-related raw pattern | 1 + 3 records    | 1 + 3 records    |


| Policy                             | Scenario attribution | Activity verification                                               | Текущий статус                                                      |
| ---------------------------------- | -------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `falco-ref-run-shell-untrusted`    | confirmed            | confirmed: G2 workload действительно запускает `/usr/bin/sh -c ...` | **scenario-related benign alert**                                   |
| `falco-ref-stdio-network-redirect` | confirmed            | пока не подтверждено, что `oldfd` был network socket                | **scenario-related policy match, activity verification unresolved** |
The Tetragon policy approximating Falco's Run shell untrusted matched the non-interactive /usr/bin/sh -c used to execute the G2 Job. The mapping is broader than the original Falco rule because it detects shell execution without reproducing Falco's full parent-process and exclusion logic.

### Tetragon Results

Across all three G2 runs, two Tetragon policies were consistently attributable to the scenario:

- `falco-ref-run-shell-untrusted`
- `falco-ref-stdio-network-redirect`

The `run-shell-untrusted` match was caused by the non-interactive `/usr/bin/sh -c` used to execute the schema-migration workload. This activity is explicitly defined in the G2 workload and was therefore independently confirmed as part of the scenario ground truth.

The `stdio-network-redirect` policy also matched the G2 container in all three runs. The mapping is broader than the corresponding Falco semantics because it matches `dup2`/`dup3` operations involving standard file descriptors without independently verifying that the source file descriptor is a network socket.

### Independent validation of `stdio-network-redirect`

A separate validation was performed with `strace -ff -yy` using the same `mariadb:11.8` image and the same G2 migration execution pattern. This validation was performed outside the three final G2 runs to avoid modifying the main experimental workload.

The validation showed that the shell created a pipe and redirected this pipe to standard input:

`dup2(3<pipe:[...]>, 0)`

A second operation redirected `/dev/null` to standard input:

`dup2(10</dev/null>, 0<pipe:[...]>)`

The child `/usr/bin/mariadb` process established the actual TCP connection to the MariaDB service separately. No network-socket-to-standard-I/O `dup2` operation was observed during the validation.

Therefore, the `stdio-network-redirect` match is interpreted as a scenario-attributable policy match caused by the broader Tetragon approximation rather than as independently confirmed network-to-standard-I/O redirection.

