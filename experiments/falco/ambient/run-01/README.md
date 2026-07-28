# Ambient Run 01

Status: Excluded

The run was excluded because a Falco container restarted during the
observation period.

The restart count of the Falco Pod on worker2 changed from 0 to 1
during the run. The collected logs contain Falco startup messages
inside the observation window.

Subsequent troubleshooting showed repeated Falco process terminations
with exit code 1 on all three cluster nodes.

The run was therefore excluded from the experimental dataset.