01 run
Scenario completed: YES
Falco restart during run: NO
Falco alerts: 0

02 run
Scenario completed: YES
Falco restart during run: NO
Alerts during window: 0
Scenario-related alerts: 0
Unrelated/ambient alerts: 0

03 run
Scenario completed: YES
Falco restart during run: NO
Alerts during window: 0
Scenario-related alerts: 0
Unrelated/ambient alerts: 0



Create folder
1.$run = ".\experiments\falco\exploratory-unstable\G2\run-01"
New-Item -ItemType Directory -Force -Path $run | Out-Null

Delete previoud job
2. k delete job g2-schema-migration -n database --ignore-not-found

Check falco befor run
3. k get pods -n falco -o wide |
  Tee-Object -FilePath "$run\falco-pods-before.txt"

  Save start time
4. $startTime = (Get-Date).ToUniversalTime().ToString("o")

$startTime |
  Out-File "$run\start-time.txt" -Encoding utf8

Run
5. k apply -f .\tests\scenarios\G2-schema-migration\g2-schema-migration.yaml

Fix the end
6. $endTime = (Get-Date).ToUniversalTime().ToString("o")

$endTime |
  Out-File "$run\end-time.txt" -Encoding utf8

7. fix result of scenario

k logs job/g2-schema-migration -n database |
  Tee-Object -FilePath "$run\g2-output.txt"

8. check falco pods
k get pods -n falco -o wide |
  Tee-Object -FilePath "$run\falco-pods-after.txt"

9. collect logs
k logs -n falco `
  -l app.kubernetes.io/name=falco `
  -c falco `
  --since-time=$startTime `
  --timestamps `
  --prefix 2>&1 |
  Out-File "$run\falco-logs-from-start.txt" -Encoding utf8
10. delete job
k delete job g2-schema-migration -n database --ignore-not-found

Remove-Variable startTime, endTime -ErrorAction SilentlyContinue