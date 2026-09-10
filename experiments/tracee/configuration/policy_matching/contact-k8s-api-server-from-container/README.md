# k8s_api_connection (Falco: Contact K8S API Server From Container)

intention match,
mechanism not


### What for
Процесс внутри контейнера пытается подключиться к Kubernetes API Server?
Kubernetes API manage the cluster, through kubernetes processe can comunicate get pod information, get secrets and change resources.

if workload container (e.x web-container) want smth from Kubernetes api -> suspicious
calico-node → Kubernetes API (exception ->it is ok)

### how falco does
Kubernetes API Server
= kubernetes.default.svc.cluster.local 


процесс находится в контейнере?
        ↓
он устанавливает network connection?
        ↓
destination = Kubernetes API Server?
        ↓
это известный легитимный Kubernetes component? -> uses exceptions
        ↓
нет
        ↓
ALERT

### how tracee does
узнать API IP из KUBERNETES_SERVICE_HOST
+
увидеть connection к этому IP

Tracee does not has exception -> e.x calico is kubernetes component and ok if do connection to kub api, but tracee alert it


## Positive test 
experiments\tracee\configuration\policy_matching\contact-k8s-api-server-from-container\positive.yaml

worker1 tries to access kub api

(failed) if tracee-config-fixed with exec-env: false
success if exec-env: true

## Negative

worker1 connects to Mariadb:
sucess (empty \negative-tracee-events.jsonl)