G4b — Authorized Interactive kubectl exec
Run: 01

Scenario completed successfully: yes
Falco restart during scenario: no

Falco alerts observed: 1

Rule:
A shell was spawned in a container with an attached terminal

Priority:
Notice

Scenario-related alerts: 1

Classification:
benign security alert / operational false positive

Run: 02
Scenario completed successfully: yes
Falco restart during scenario: no
Falco alerts observed: 1
Scenario-related alerts: 1
Result: valid

Run 03
Scenario completed successfully: yes
Falco restart during scenario: no
Falco alerts observed: 1
Scenario-related alerts: 1
Rule: A shell was spawned in a container with an attached terminal

Summary:
The same Falco alert was observed in all three runs.

[pod/falco-vf8rj/falco] 2026-07-29T13:55:07.478104653Z 13:55:07.476277048: Notice A shell was spawned in a container with an attached terminal | evt_type=execve user=mysql user_uid=999 user_loginuid=-1 process=sh proc_exepath=/usr/bin/dash parent=runc command=sh terminal=34816 exe_flags=EXE_LOWER_LAYER container_id=e953069bb09e container_name=<NA> container_image_repository=<NA> container_image_tag=<NA> k8s_pod_name=<NA> k8s_ns_name=<NA>