### Before run

```powershell
k get pods -n falco -o wide
k get pods -n database -o wide
```

### Delete previous Job
k delete job g1-crud -n database --ignore-not-found

### Run G1
k apply -f .\tests\scenarios\G1-crud\g1-crud.yaml

### Wait
k wait `
  --for=condition=Complete `
  job/g1-crud `
  -n database `
  --timeout=120s

### Check the results

k logs job/g1-crud -n database


1. Scenario completed successfully?
2. Did Falco remain running during the complete window?
3. Which Falco alerts occurred during the scenario window?

Falco:
no restart during scenario

Alerts:
0


G1 run 2

Scenario:
SUCCESS

Falco:
no restart during scenario

Alerts:
0

G1 run 3

Scenario:
SUCCESS

Falco:
no restart during scenario

Alerts:
0