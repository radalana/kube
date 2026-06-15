# Hetzner MicroK8s Cluster

## Current cluster

| Host | Public IP | Private IP | SSH alias | Notes |
|---|---|---|---|---|
| master | 178.105.154.188 | 10.0.0.2 | master | control-plane |
| worker1 | 178.105.234.33 | 10.0.0.3 | worker1 | joined node |

## Planned

| Host | Private IP | SSH alias |
|---|---|---|
| worker2 | 10.0.0.x | worker2 |

## Local access

Start SSH tunnel:

```powershell
ssh -N tunnel