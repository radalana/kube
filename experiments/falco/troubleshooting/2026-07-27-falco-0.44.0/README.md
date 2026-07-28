# Falco 0.44.0 Stability Test

Status: Failed

Falco 0.44.0 was installed with the modern eBPF driver on the
unchanged three-node cluster.

The Falco container on the master node restarted approximately
40 minutes after startup.

The previous container terminated with exit code 1. The final log
message reported a parsing error for a clone3 event:

`could not parse param 1 (exe) ... type 335 (clone3) ...
expected length 2, found 5`

A similar clone3 parsing failure had previously been observed with
Falco 0.44.1.

Falco 0.44.0 was therefore not selected for the formal experiment.