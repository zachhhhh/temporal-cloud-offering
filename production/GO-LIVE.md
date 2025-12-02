# Go Live Guide - Temporal Cloud

## Current Status ✅

| Component           | Status     | URL                   |
| ------------------- | ---------- | --------------------- |
| **Temporal Server** | ✅ Running | localhost:7233        |
| **Temporal UI**     | ✅ Running | http://localhost:8080 |
| **Billing API**     | ✅ Running | http://localhost:8082 |
| **Admin Portal**    | ✅ Running | http://localhost:3000 |
| **PostgreSQL**      | ✅ Running | localhost:5432        |
| **Prometheus**      | ✅ Running | http://localhost:9090 |
| **Grafana**         | ✅ Running | http://localhost:3001 |

## OCI K3s Cluster

- **Load Balancer IP**: `138.2.104.236`
- **Status**: Infrastructure created, instances provisioning
- **Note**: OCI ARM capacity is limited, may take time

## Option 1: Deploy to VPS (Fastest)

Deploy to any VPS (DigitalOcean, Linode, Vultr, Hetzner):

```bash
# 1. SSH to your VPS
ssh root@your-vps-ip

# 2. Install Docker
curl -fsSL https://get.docker.com | sh

# 3. Clone the repo
git clone https://github.com/yourusername/temporal-cloud-offering.git
cd temporal-cloud-offering

# 4. Configure environment
cp production/.env.example production/.env
nano production/.env  # Edit with your values

# 5. Generate SSL certificates (using Let's Encrypt)
mkdir -p production/ssl
# Use certbot or acme.sh to generate certs

# 6. Start production stack
cd production
docker-compose -f docker-compose.prod.yaml up -d

# 7. Verify
curl http://localhost:8082/health
```

## Option 2: Deploy to OCI K3s (When Ready)

```bash
# 1. Get kubeconfig from K3s server
ssh -i ~/.oci/oci_api_key.pem ubuntu@138.2.104.236 \
  "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config-oci

# 2. Update server address in kubeconfig
sed -i 's/127.0.0.1/138.2.104.236/g' ~/.kube/config-oci

# 3. Set kubeconfig
export KUBECONFIG=~/.kube/config-oci

# 4. Deploy
./production/deploy-to-k8s.sh deploy
```

## Option 3: Deploy to Any Kubernetes

```bash
# 1. Set your kubeconfig
export KUBECONFIG=/path/to/your/kubeconfig

# 2. Build and push images
export DOCKER_REGISTRY=ghcr.io/yourusername
./production/deploy-to-k8s.sh build

# 3. Deploy
./production/deploy-to-k8s.sh deploy
```

## DNS Configuration

Point these domains to your server IP:

| Domain                    | Purpose                         |
| ------------------------- | ------------------------------- |
| `app.yourdomain.com`      | Admin Portal                    |
| `api.yourdomain.com`      | Billing API                     |
| `temporal.yourdomain.com` | Temporal UI                     |
| `grpc.yourdomain.com`     | Temporal gRPC (SDK connections) |

## SSL Certificates

### Using Certbot (Recommended)

```bash
apt install certbot
certbot certonly --standalone -d app.yourdomain.com -d api.yourdomain.com -d temporal.yourdomain.com
cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem production/ssl/
cp /etc/letsencrypt/live/yourdomain.com/privkey.pem production/ssl/
```

### Using Kubernetes cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
kubectl apply -f production/k8s-manifests/08-cert-manager.yaml
```

## Stripe Configuration

1. Create Stripe account at https://stripe.com
2. Get API keys from Dashboard > Developers > API keys
3. Set up webhook:
   - URL: `https://api.yourdomain.com/webhooks/stripe`
   - Events: `invoice.paid`, `invoice.payment_failed`, `customer.subscription.*`
4. Update `.env` with keys

## Post-Deployment Checklist

- [ ] DNS records configured
- [ ] SSL certificates installed
- [ ] Stripe keys configured
- [ ] Test organization creation
- [ ] Test namespace creation
- [ ] Test workflow execution
- [ ] Test billing flow
- [ ] Set up monitoring alerts
- [ ] Configure backups

## Verify Deployment

```bash
# Health checks
curl https://api.yourdomain.com/health
curl https://app.yourdomain.com
curl https://temporal.yourdomain.com

# Test SDK connection
temporal workflow list --address grpc.yourdomain.com:443 --tls

# Run E2E tests
./tests/e2e/full_flow_test.sh
```

## Monitoring

- **Grafana**: https://grafana.yourdomain.com (admin/admin)
- **Prometheus**: https://prometheus.yourdomain.com
- **Temporal Metrics**: Available in Grafana dashboards

## Support

- **Docs**: https://docs.yourdomain.com
- **Community**: https://community.yourdomain.com
- **Status**: https://status.yourdomain.com
