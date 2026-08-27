alco-ref-k8s-api-contact

# Зачем нужно такое правило?
так как необычно, что обычный worklpad pod/container обращается к Kubernetes API.
Например через контейнер приложения и с досутпом к ServiceAccount token делает запрос на https://kubernetes.default.svc.cluster.local для read secrete например
«Почему этот контейнер вообще разговаривает с control plane?»

# Как работет в Falco
connect
+
IPv4/IPv6
+
container
+
destination = kubernetes.default.svc.cluster.local
+
NOT known Kubernetes containers

# Как выполнено в v3.2

tcp connection
+ 
примерно container context     ==> очень широкое на все tcp 443: Pod → google.com:443 MATCH
+ 
destination port = 443

НЕТ:
destination = Kubernetes API
NOT known Kubernetes container
* т.е контейнер не входит в список Kubernetes-компонентов, которые Falco заранее считает ожидаемыми для обращения к API Server.

# Идея имплементации через hook типа sock

- call: tcp_connect это такой хук
  syscall: false
  args:
    - index: 0
      type: sock
      label: socket


## Недостаток/ ограничение выбранного подхода
Для твоего фиксированного экспериментального кластера это очень хорошее приближение, но IP-based match не является универсальным эквивалентом DNS/service-name semantics Falco.

### Implementation
1. check ip adress API Service 
    k get svc kubernetes -n default -o wide

    k get svc kubernetes -n default `
  -o jsonpath='{.spec.clusterIP}'
2. k apply `
  -f .\experiments\tetragon\policies\policy_matching\v4\falco-k8s-api-contact\candidate\tetragon-falco-reference-v4-candidate-k8s-api-contact.yaml

### tests
1. create Pod for both positive and negative:

k run k8s-api-v4-validation `
  -n tetragon-policy-validation `
  --image=busybox:1.36 `
  --restart=Never `
  --overrides='{"spec":{"nodeName":"worker1","containers":[{"name":"k8s-api-v4-validation","image":"busybox:1.36","command":["sleep","600"]}]}}'
2. start capture
$tp = k get pods -n kube-system `
  -l app.kubernetes.io/name=tetragon `
  -o json | ConvertFrom-Json |
  Select-Object -ExpandProperty items |
  Where-Object { $_.spec.nodeName -eq "worker1" } |
  ForEach-Object { $_.metadata.name }

$tp


#### Positive:
container → 10.152.183.1:443
expected: MATCH

3. k exec `
  -n tetragon-policy-validation `
  k8s-api-v4-validation `
  -- wget -T 3 -qO- https://10.152.183.1 2>&1

#### Negative:

4. k exec `
  -n tetragon-policy-validation `
  k8s-api-v4-validation `
  -- wget -T 3 -qO- https://1.1.1.1 2>&1
container → внешний HTTPS address:443
expected: NO MATCH

daddr = 1.1.1.1
dport = 443
policy_name = falco-ref-k8s-api-contact