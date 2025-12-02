# Temporal Cloud - Hetzner Production Deployment

## Cost Estimate

| Component        | Instance             | Count | Monthly Cost |
| ---------------- | -------------------- | ----- | ------------ |
| Control Plane    | CPX21 (3 vCPU, 4GB)  | 3     | €26.94       |
| General Workers  | CPX31 (4 vCPU, 8GB)  | 2     | €29.52       |
| Temporal Workers | CPX41 (8 vCPU, 16GB) | 2     | €57.52       |
| Load Balancer    | LB11                 | 1     | €5.39        |
| Block Storage    | 100GB                | 1     | €4.40        |
| **Total**        |                      |       | **~€124/mo** |

Compare to AWS: ~$500+/mo for equivalent setup.

## Prerequisites

1. **Hetzner Account**: https://console.hetzner.cloud/
2. **API Token**: Project → Security → API Tokens → Generate
3. **SSH Key**: `ssh-keygen -t rsa -b 4096`
4. **hetzner-k3s CLI**:

   ```bash
   # macOS
   brew install vitobotta/tap/hetzner_k3s

   # Linux
   wget https://github.com/vitobotta/hetzner-k3s/releases/latest/download/hetzner-k3s-linux-amd64
   chmod +x hetzner-k3s-linux-amd64
   sudo mv hetzner-k3s-linux-amd64 /usr/local/bin/hetzner-k3s
   ```

## Quick Start

### 1. Configure

```bash
# Edit cluster.yaml and add your Hetzner API token
export HCLOUD_TOKEN="your-token-here"
sed -i '' "s/<YOUR_HETZNER_API_TOKEN>/$HCLOUD_TOKEN/" cluster.yaml
```

### 2. Create Cluster

```bash
hetzner-k3s create --config cluster.yaml
```

This takes ~3 minutes and creates:

- 3 control plane nodes (HA)
- 4 worker nodes (2 general + 2 temporal)
- Private network
- Firewall rules
- Load balancer

### 3. Verify

```bash
export KUBECONFIG=./kubeconfig
kubectl get nodes
kubectl get pods -A
```

### 4. Deploy Temporal Cloud Stack

```bash
# Apply all Kubernetes manifests
kubectl apply -f ../k8s/namespace.yaml
kubectl apply -f ../k8s/secrets.yaml
kubectl apply -f ../k8s/postgres.yaml
kubectl apply -f ../k8s/elasticsearch.yaml
kubectl apply -f ../k8s/redis.yaml
kubectl apply -f ../k8s/temporal.yaml
kubectl apply -f ../k8s/billing.yaml
kubectl apply -f ../k8s/admin-portal.yaml
kubectl apply -f ../k8s/ingress.yaml
```

## Scaling

### Manual Scaling

```bash
# Edit cluster.yaml and change instance_count
hetzner-k3s upgrade --config cluster.yaml
```

### Autoscaling

Autoscaling is enabled for the general worker pool (2-5 nodes).
The cluster autoscaler will add nodes when pods are pending.

## Upgrades

```bash
# Upgrade k3s version
hetzner-k3s upgrade --config cluster.yaml --new-k3s-version v1.29.0+k3s1
```

## Backup

```bash
# Backup etcd (run on a master node)
k3s etcd-snapshot save --name backup-$(date +%Y%m%d)
```

## Delete Cluster

```bash
hetzner-k3s delete --config cluster.yaml
```

## Monitoring

- Grafana: https://grafana.your-domain.com
- Prometheus: Internal only (port-forward)

## Security Notes

1. **Firewall**: Only SSH (22), HTTP (80), HTTPS (443), and K8s API (6443) are exposed
2. **Private Network**: All inter-node communication uses private IPs
3. **Encryption**: Enable at-rest encryption for sensitive workloads
