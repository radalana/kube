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
# Configure kubelet to advertise the node's private network IP as InternalIP
# Run this on each node and replace 10.0.0.X with the node's own private IP
```bash
sudo cp /var/snap/microk8s/current/args/kubelet /var/snap/microk8s/current/args/kubelet.bak
sudo sed -i '/--node-ip=/d' /var/snap/microk8s/current/args/kubelet
echo "--node-ip=10.0.0.X" | sudo tee -a /var/snap/microk8s/current/args/kubelet
sudo snap restart microk8s
```

# Configure Calico to use each node's Kubernetes InternalIP as its Calico node IP
# Run this on the master node after kubelet --node-ip was set on every node
```bash
sudo cp /var/snap/microk8s/current/args/cni-network/cni.yaml /var/snap/microk8s/current/args/cni-network/cni.yaml.bak
sudo sed -i 's/can-reach=10\.0\.0\.3/kubernetes-internal-ip/' /var/snap/microk8s/current/args/cni-network/cni.yaml
# Check that the Calico autodetection method was changed
sudo grep -n "IP_AUTODETECTION_METHOD" -A2 /var/snap/microk8s/current/args/cni-network/cni.yaml
# Apply the updated Calico manifest
microk8s kubectl apply -f /var/snap/microk8s/current/args/cni-network/cni.yaml
# Restart Calico pods so the new autodetection method is used
k rollout restart daemonset/calico-node -n kube-system

