apiVersion: v1
kind: Pod
metadata:
  name: tracee-private-key-negative
  namespace: default
spec:
  nodeName: worker1
  restartPolicy: Never
  containers:
    - name: test
      image: alpine:3.22
      command:
        - /bin/sh
        - -c
        - |
          echo "ordinary text" > /tmp/test-file
          grep "ordinary text" /tmp/test-file
          sleep 3