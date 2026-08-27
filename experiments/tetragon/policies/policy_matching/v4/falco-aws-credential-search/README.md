aws-credential-search
aws-credential-search

Falco reference rule:
AWS credential search based partly on process arguments

Environment applicability:
not applicable
→ no AWS usage in the experimental environment/scenarios

Tetragon v3.2 mapping:
too broad
→ grep/find execution only

Decision:
REMOVE / NOT INCLUDE in final v4 mapping

Reason:
No sufficiently equivalent policy-level mapping was identified,
and the rule is not applicable to the predefined workload.
Keeping the broad approximation would introduce detections
that do not represent the Falco reference condition.