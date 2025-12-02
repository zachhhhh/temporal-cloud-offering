# Oracle Cloud Free Tier - Temporal Cloud

## What You Get FREE Forever

Oracle offers the most generous free tier:

| Resource           | Free Allowance                             |
| ------------------ | ------------------------------------------ |
| **ARM VMs**        | 4 OCPUs, 24GB RAM (can be 1x24GB or 4x6GB) |
| **AMD VMs**        | 2 VMs, 1GB RAM each                        |
| **Block Storage**  | 200GB total                                |
| **Object Storage** | 10GB                                       |
| **Load Balancer**  | 1 flexible LB                              |
| **Bandwidth**      | 10TB/month outbound                        |

## Recommended Setup (FREE)

```
1x ARM VM (Ampere A1): 4 OCPU, 24GB RAM
- Runs: K3s + Temporal + PostgreSQL + Elasticsearch + All services
- Cost: $0/month
```

## Setup Steps

### 1. Create Oracle Cloud Account

https://www.oracle.com/cloud/free/

### 2. Create ARM VM

```bash
# In Oracle Cloud Console:
# Compute -> Instances -> Create Instance
# - Shape: VM.Standard.A1.Flex (ARM)
# - OCPUs: 4
# - Memory: 24GB
# - Image: Ubuntu 22.04
# - Add SSH key
```

### 3. Install K3s

```bash
ssh ubuntu@<VM_IP>

# Install K3s
curl -sfL https://get.k3s.io | sh -

# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml
```

### 4. Deploy Temporal Stack

```bash
# Copy kubeconfig locally, then:
export KUBECONFIG=./oracle-kubeconfig.yaml

# Apply manifests (use minimal versions)
kubectl apply -f ../k8s-minimal/
```

## Limitations

- ARM architecture (most images support it now)
- Single region (choose closest to your users)
- No HA (acceptable for early stage)
- May need to wait for ARM capacity in popular regions

## Tips

1. **Choose less popular region** - ARM VMs are in high demand
   - Try: US-Ashburn, UK-London, Germany-Frankfurt
2. **Create VM immediately** after account creation

   - Free tier VMs get claimed fast

3. **Use ARM-compatible images**:
   - `temporalio/server:latest` ✅
   - `temporalio/ui:latest` ✅
   - `postgres:15-alpine` ✅
   - `elasticsearch:7.17.9` ✅
