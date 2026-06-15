# SSH and network

- master has public IP and private IP.
- worker1 has public IP and private IP.
- Kubernetes node traffic should use private IPs.
- Local kubectl connects through SSH tunnel.
- SSH config is stored outside the project in ~/.ssh/config.