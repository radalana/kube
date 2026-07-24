# Controlled Alert Validation

This validation checks whether Falco detects runtime activity. It is a technical functionality test and is not part of the G1-G7 scenario results.

## 1. Create a temporary Pod

```powershell
k run falco-validation `
  --namespace falco `
  --image=alpine `
  --restart=Never `
  --command -- sleep 300
```

## 2. Wait until the Pod is ready

```powershell
k wait `
  --namespace falco `
  --for=condition=Ready `
  pod/falco-validation `
  --timeout=60s
```

## 3. Open an interactive shell

```powershell
k exec -it `
  --namespace falco `
  falco-validation `
  -- sh
```

Inside the shell, run:

```sh
id
exit
```

## 4. Collect Falco logs

```powershell
$evidenceDir = "experiments/falco/validation/run-01/evidence"
$logFile = "$evidenceDir/falco-alerts.txt"

New-Item `
  -ItemType Directory `
  -Force `
  -Path $evidenceDir |
  Out-Null

New-Item `
  -ItemType File `
  -Force `
  -Path $logFile |
  Out-Null

k logs -n falco `
  -l app.kubernetes.io/name=falco `
  -c falco `
  --since=15m `
  --timestamps `
  --prefix 2>&1 |
  Tee-Object -FilePath $logFile
```

Falco generated the following alert:

```text
Notice A shell was spawned in a container with an attached terminal
```

The alert confirmed that Falco detected the interactive shell execution and evaluated the event through its ruleset.

## 5. Delete the temporary Pod

```powershell
k delete pod falco-validation -n falco
```

The temporary Pod was removed before the ambient monitoring period.

## Result

The controlled alert validation was successful.

This validation was used only as a technical functionality test. It was excluded from the ambient monitoring and the G1-G7 scenario results.

The collected Falco logs are stored in:

- [`run-01/evidence/falco-alerts.txt`](run-01/evidence/falco-alerts.txt)