# Cluster smoke tests
These tests verify that Kubernetes DNS and dynamic storage provisioning work
before application workloads are deployed.

Run these tests after completing:

- `02-microk8s-cluster.md`
- `03-local-kubectl.md`

The tests verify:

- Kubernetes DNS
- Pod networking
- dynamic PersistentVolume provisioning
## 1. Test Kubernetes DNS
### Create test resources (from root of projekt)
```bash
k apply -f .\tests\smoke\Namespace.yaml
k apply -f .\tests\smoke\dns-test.yaml
```
### Test commands
- Wait till dns-test pod is ready
```bash
k wait --for=condition=Ready pod/dns-test -n cluster-test --timeout=120s
```
- check DNS from container inside pod to request ip adress of kubernetes.default.svc.cluster.local
```bash
k exec -n cluster-test dns-test -- nslookup kubernetes.default.svc.cluster.local