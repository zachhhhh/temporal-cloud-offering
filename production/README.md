# Temporal Cloud - Production Deployment

Deploy Temporal Cloud Offering with real domains, SSL, and OAuth/SSO.

## Deployment Options

| Option                                                    | Cost    | Best For                     |
| --------------------------------------------------------- | ------- | ---------------------------- |
| [**Cloudflare Tunnel**](./cloudflare-tunnel/)             | $0      | Local dev, demos, beta users |
| [**Oracle Cloud Free Tier**](./free-tier/oracle-cloud.md) | $0      | Production (limited scale)   |
| [**Hetzner Cloud**](./hetzner/)                           | ~$10/mo | Production (scalable)        |

## Quick Start: Cloudflare Tunnel (Recommended)

Expose your local services with a real domain in 5 minutes:

```bash
# 1. Start local services
cd deploy && docker-compose up -d

# 2. Setup tunnel
cd production/cloudflare-tunnel
./setup-tunnel.sh

# 3. Run tunnel
./run-tunnel.sh
```

Your services are now at:

- **Admin Portal**: https://app.YOUR_DOMAIN
- **Temporal UI**: https://temporal.YOUR_DOMAIN
- **Grafana**: https://grafana.YOUR_DOMAIN

See [cloudflare-tunnel/README.md](./cloudflare-tunnel/README.md) for OAuth/SSO setup.

---

## Oracle Cloud Architecture (Free Tier)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Oracle Cloud (Free Tier)                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │ K3s Server  │  │ K3s Worker  │  │ K3s Worker  │              │
│  │ (ARM 4CPU)  │  │ (ARM 4CPU)  │  │ (ARM 4CPU)  │              │
│  │   12GB RAM  │  │   12GB RAM  │  │   12GB RAM  │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│         │                │                │                      │
│         └────────────────┼────────────────┘                      │
│                          │                                       │
│                 ┌────────┴────────┐                              │
│                 │  Load Balancer  │                              │
│                 │   (Free Tier)   │                              │
│                 └────────┬────────┘                              │
└────────────────────────────────────────────────────────────────┘
                           │
                    ┌──────┴──────┐
                    │   Internet  │
                    └─────────────┘
```

## Cost: $0/month

Oracle Cloud Always Free Tier includes:

- **4 ARM Ampere A1 OCPUs** (can be split across VMs)
- **24GB RAM** total
- **200GB Block Storage**
- **10TB Outbound Data**
- **2 Load Balancers**

## Quick Start

### Prerequisites

```bash
# Install tools (macOS)
brew install terraform kubectl helm oci-cli

# Configure OCI CLI
oci setup config
```

### Deploy

```bash
cd production

# One-command deployment
./deploy-oci.sh deploy
```

This will:

1. Create K3s cluster with Terraform
2. Install Longhorn (storage), Cert-Manager (SSL), Nginx Ingress
3. Deploy Temporal, PostgreSQL, Redis, Billing API
4. Configure load balancer and SSL

### Manual Deployment

```bash
# Step 1: Deploy infrastructure
cd terraform-oci
terraform init
terraform plan -out=.tfplan
terraform apply .tfplan

# Step 2: Get kubeconfig
SERVER_IP=$(terraform output -raw k3s_servers_ips | tr -d '[]"')
scp -i ~/.ssh/oracle_temporal ubuntu@$SERVER_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/config-oci
export KUBECONFIG=~/.kube/config-oci

# Step 3: Deploy Temporal stack
cd ../helm/temporal-cloud
helm dependency update
helm install temporal-cloud . -n temporal-cloud --create-namespace
```

## Configuration

### terraform-oci/terraform.tfvars

```hcl
# OCI Authentication (get from OCI Console)
tenancy_ocid     = "ocid1.tenancy.oc1..xxx"
user_ocid        = "ocid1.user.oc1..xxx"
fingerprint      = "xx:xx:xx:xx"
private_key_path = "~/.oci/oci_api_key.pem"

# Region
region              = "ap-singapore-1"
availability_domain = "ldIz:AP-SINGAPORE-1-AD-1"

# Cluster
cluster_name = "temporal-cloud"
os_image_id  = "ocid1.image.oc1..."  # Oracle Linux ARM

# Security
my_public_ip_cidr         = "YOUR_IP/32"
certmanager_email_address = "your@email.com"
```

### helm/temporal-cloud/values.yaml

```yaml
global:
  domain: "yourdomain.com"

temporalUI:
  ingress:
    hosts:
      - host: temporal.yourdomain.com

billing:
  ingress:
    hosts:
      - host: api.yourdomain.com
```

## Directory Structure

```
production/
├── deploy-oci.sh           # One-click deployment script
├── terraform-oci/          # Terraform IaC
│   ├── main.tf             # Main configuration
│   ├── variables.tf        # Variable definitions
│   ├── terraform.tfvars    # Your values (gitignored)
│   └── k3s-oci-cluster/    # K3s module (git submodule)
├── helm/
│   └── temporal-cloud/     # Helm chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── k8s-minimal/            # Raw K8s manifests (alternative)
└── oracle/                 # Oracle-specific scripts
```

## Operations

### Access Cluster

```bash
export KUBECONFIG=~/.kube/config-oci
kubectl get nodes
kubectl get pods -n temporal-cloud
```

### View Logs

```bash
kubectl logs -f deployment/temporal-cloud-temporal -n temporal-cloud
```

### Scale

```bash
# Edit terraform.tfvars
k3s_worker_pool_size = 3

# Apply
terraform apply
```

### Upgrade Temporal

```bash
helm upgrade temporal-cloud ./helm/temporal-cloud -n temporal-cloud
```

### Destroy

```bash
./deploy-oci.sh destroy
# or
cd terraform-oci && terraform destroy
```

## Troubleshooting

### "Out of host capacity" Error

ARM instances are in high demand. Try:

1. Different availability domain
2. Different region (subscribe in OCI Console)
3. Wait and retry later
4. Use AMD micro instances (1GB RAM) as fallback

### SSL Certificate Issues

```bash
# Check cert-manager
kubectl get certificates -n temporal-cloud
kubectl describe certificate temporal-ui-tls -n temporal-cloud

# Check logs
kubectl logs -n cert-manager deployment/cert-manager
```

### Pod Stuck in Pending

```bash
# Check events
kubectl describe pod <pod-name> -n temporal-cloud

# Check storage
kubectl get pvc -n temporal-cloud
```

## Security Notes

1. **Never commit** `terraform.tfvars` or `*.pem` files
2. **Rotate API keys** periodically
3. **Use secrets** for sensitive values in Helm
4. **Enable firewall** rules in OCI Console

## Support

- [Temporal Documentation](https://docs.temporal.io)
- [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
- [K3s Documentation](https://docs.k3s.io)
