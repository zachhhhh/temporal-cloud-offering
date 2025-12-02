# Temporal Cloud - OCI Deployment Options

## Cost Comparison

| Option              | Monthly Cost | After $300 Credits | Pros                            | Cons                |
| ------------------- | ------------ | ------------------ | ------------------------------- | ------------------- |
| **OKE + Free VMs**  | $0           | $0                 | Managed K8s, auto-updates, HA   | Slower provisioning |
| **K3s on Free VMs** | $0           | $0                 | Fast, lightweight, full control | Manual management   |
| **OKE + Paid VMs**  | ~$40         | ~$40               | More resources, faster          | Costs money         |

## Recommendation

### For Production: **OKE with Always Free VMs** ✅

```
OKE Control Plane: FREE (Oracle managed)
Worker Nodes: 2x VM.Standard.A1.Flex (ARM)
  - 2 OCPU + 12GB RAM each
  - Total: 4 OCPU + 24GB RAM
  - Cost: $0 (Always Free)
```

**Why OKE?**

1. **Free control plane** - Oracle manages etcd, API server, scheduler
2. **Auto-updates** - Security patches applied automatically
3. **Native integration** - Load balancers, block storage, IAM
4. **HA ready** - Easy to scale when needed
5. **OCI CLI support** - Easy kubeconfig management

### For Development/Testing: **K3s on Free VMs**

Good for quick iteration, but requires manual management.

## Quick Start

### Option A: OKE (Recommended)

```bash
cd production/terraform-oke

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your OCI credentials

# Deploy
terraform init
terraform plan
terraform apply

# Get kubeconfig
oci ce cluster create-kubeconfig \
  --cluster-id <cluster-id> \
  --file ~/.kube/config \
  --region ap-singapore-1 \
  --token-version 2.0.0

# Deploy Temporal
kubectl apply -f ../k8s-minimal/
```

### Option B: K3s (Current)

```bash
cd production/terraform-oci

# Already configured
./deploy-retry.sh  # Runs until successful
```

## Resource Allocation for Temporal

### Minimum (Free Tier - 4 OCPU, 24GB)

| Component         | CPU | Memory |
| ----------------- | --- | ------ |
| Temporal Server   | 0.5 | 2GB    |
| Temporal UI       | 0.1 | 256MB  |
| PostgreSQL        | 0.5 | 2GB    |
| Elasticsearch     | 1.0 | 4GB    |
| Billing Service   | 0.1 | 256MB  |
| Usage Collector   | 0.1 | 128MB  |
| Admin Portal      | 0.1 | 256MB  |
| **System/Buffer** | 1.6 | 15GB   |
| **Total**         | 4.0 | 24GB   |

### Recommended (With Credits)

Add more nodes for:

- High availability (3+ nodes)
- More Temporal workers
- Prometheus/Grafana monitoring
- Redis for caching

## Scaling Strategy

### Phase 1: Free Tier ($0/month)

- 2 ARM nodes, 4 OCPU, 24GB
- Single Temporal server
- PostgreSQL (no HA)
- Basic monitoring

### Phase 2: Growth (~$50/month)

- 3 ARM nodes, 6 OCPU, 36GB
- Temporal server with 2 replicas
- PostgreSQL with read replica
- Full monitoring stack

### Phase 3: Production (~$150/month)

- 4+ ARM nodes, 8+ OCPU, 48GB+
- Temporal HA (3 replicas)
- PostgreSQL HA
- Elasticsearch cluster
- CDN for admin portal

## OCI Free Tier Limits

### Always Free (Forever)

- **Compute**: 4 OCPU, 24GB RAM (ARM A1.Flex)
- **Block Storage**: 200GB total
- **Object Storage**: 20GB
- **Load Balancer**: 1 flexible (10Mbps)
- **Databases**: 2 Autonomous DBs (20GB each)
- **Monitoring**: 500M ingestion, 10 alarms

### $300 Credits (30 days)

- Use for initial setup and testing
- Try larger instances
- Test paid features
- Build confidence before going free-tier only

## Migration Path

If starting with K3s and want to move to OKE:

1. Export data from PostgreSQL
2. Create OKE cluster
3. Deploy same K8s manifests
4. Import data
5. Update DNS
6. Destroy K3s cluster

Both use standard Kubernetes, so manifests are portable!
