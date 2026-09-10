positive: passt
eventName: sched_process_exec
cmdpath: /proc/self/fd/3
pathname: memfd:tracee-memfd-test
matchedPolicies: ["falco-ref-memfd-execution"]


negative: passs



memfd-pos
memfd:*          -> memfd rule SHOULD match

memfd-neg
/dev/shm/*       -> memfd rule SHOULD NOT match