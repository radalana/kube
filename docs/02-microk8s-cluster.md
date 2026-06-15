# MicroK8s cluster setup

Install MicroK8s:

```bash
sudo snap install microk8s --classic --channel=1.35/stable
sudo usermod -a -G microk8s $USER
mkdir -p ~/.kube
chmod 0700 ~/.kube
su - $USER
microk8s status --wait-ready
```
# Add worker-1 node
```bash
microk8s add-node
```