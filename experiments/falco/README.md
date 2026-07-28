# Falco Experiment

## Purpose

This directory contains the commands and evidence used for the Falco experiment. The verified baseline cluster state is stored in `experiments/baseline`.

Falco was installed after the baseline state was verified and after all G1-G7 scenario validation Jobs and Pods were removed.

## Installation

The official Falco Helm repository was added and updated:

```powershell
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
```

Falco was installed in the existing `falco` namespace:

```powershell
helm install falco `
  --namespace falco `
  --version 9.1.0 `
  --set tty=true `
  --set driver.kind=modern_ebpf `
  --set falcoctl.artifact.follow.enabled=false `
  falcosecurity/falco
```

Installed versions:

* Helm chart: `9.1.0`
* Falco: `0.44.1`
* Driver: `modern_ebpf`
* Installation date: `2026-07-24`

The chart version was specified explicitly to keep the installation reproducible.

Automatic artifact updates were disabled with `falcoctl.artifact.follow.enabled=false`. This prevents the Falco rules from changing during the experiment.

## Installation Validation

### Helm release

```powershell
helm list -n falco
```

Relevant output:

```text
NAME    NAMESPACE   REVISION   STATUS     CHART         APP VERSION
falco   falco       1          deployed   falco-9.1.0   0.44.1
```

The Helm release was deployed successfully.

### DaemonSet

```powershell
kubectl get daemonset -n falco
```

Relevant output:

```text
NAME    DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
falco   3         3         3       3            3
```

The DaemonSet started one Falco Pod on each of the three cluster nodes.

### Pods

```powershell
kubectl get pods -n falco -o wide
```

Relevant output:

```text
NAME          READY   STATUS    RESTARTS   NODE
falco-8zpfq   1/1     Running   0          master
falco-dqbfz   1/1     Running   0          worker2
falco-kqjk8   1/1     Running   0          worker1
```

All Falco Pods were running, ready, and had zero restarts.

### Driver and event source

```powershell
kubectl logs -n falco `
  -l app.kubernetes.io/name=falco `
  -c falco `
  --tail=100 `
  --prefix
```

Relevant output:

```text
Falco version: 0.44.1 (x86_64)
Loaded event sources: syscall
Enabled event sources: syscall
Opening 'syscall' source with modern BPF probe.
One ring buffer every '2' CPUs.
```

The logs confirmed that Falco version `0.44.1` started successfully, enabled the `syscall` event source, and used the modern eBPF probe.

The following non-fatal message was also present:

```text
libpman: disabled BPF iterators
(not running in the root PID namespace, or failed to determine it)
```

Falco continued running after this message. All three Pods remained ready with zero restarts, and the syscall source was opened successfully.

## Result

The Falco installation passed the initial validation:

* Helm release status was `deployed`;
* three Falco Pods were running;
* one Falco Pod was present on each node;
* all Pods were ready with zero restarts;
* the syscall event source was enabled;
* the modern eBPF probe was active.

Falco was ready for the controlled alert validation and ambient monitoring.


The complete installation and validation outputs are stored in
[`install/evidence`](install/evidence/).


## Controlled Alert Validation

After installation, a temporary validation Pod was created to verify that
Falco was able to observe runtime activity and generate an alert.

This validation run is not part of the G1-G7 scenario results.
The evidence is stored in:

```text
experiments/falco/validation/run-01/evidence/

in /validation - proofs that falco generates alerst 
1. Установить Falco
2. Дождаться Ready
3. Сохранить install evidence
4. Провести controlled alert validation
5. Удалить validation Pod
6. Подождать 180 секунд
7. Начать ambient run


Start-Sleep -Seconds 180