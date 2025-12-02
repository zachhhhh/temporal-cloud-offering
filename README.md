# Temporal Cloud Offering

A monetizable Temporal-as-a-Service platform built on official Temporal components.

## Quick Start (5 minutes)

```bash
# 1. Start services locally
cd deploy && docker-compose up -d

# 2. Expose with real domain + SSL (optional)
cd ../production/cloudflare-tunnel
./setup-tunnel.sh
./run-tunnel.sh
```

**Local Access:**

- Admin Portal: http://localhost:3000
- Temporal UI: http://localhost:8080
- Grafana: http://localhost:3001

**With Cloudflare Tunnel:**

- Admin Portal: https://app.YOUR_DOMAIN
- Temporal UI: https://temporal.YOUR_DOMAIN
- Grafana: https://grafana.YOUR_DOMAIN

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Customer Access                              │
├─────────────────────────────────────────────────────────────────────┤
│  Temporal UI (temporalio/ui)  │  Admin Portal (billing/usage)       │
│  https://temporal.domain.com  │  https://app.domain.com             │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                          Cloudflare Tunnel (SSL + OAuth)
                                   │
┌─────────────────────────────────────────────────────────────────────┐
│                         Cloud Services                               │
├──────────────────┬──────────────────┬───────────────────────────────┤
│  Billing Service │  Usage Collector │  Cloud API (cloud-sdk-go)     │
│  (Stripe + DB)   │  (Prometheus)    │  Namespace provisioning       │
└──────────────────┴──────────────────┴───────────────────────────────┘
                                   │
┌─────────────────────────────────────────────────────────────────────┐
│                      Temporal Infrastructure                         │
├─────────────────────────────────────────────────────────────────────┤
│  Temporal Server (temporalio/auto-setup)                            │
│  PostgreSQL │ Elasticsearch │ Prometheus │ Grafana                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Deployment Options

| Option                                                   | Cost    | Setup Time | Best For               |
| -------------------------------------------------------- | ------- | ---------- | ---------------------- |
| [**Cloudflare Tunnel**](production/cloudflare-tunnel/)   | $0      | 5 min      | Demos, beta users, dev |
| [**Oracle Cloud**](production/free-tier/oracle-cloud.md) | $0      | 30 min     | Production (free tier) |
| [**Hetzner**](production/hetzner/)                       | ~$10/mo | 20 min     | Production (scalable)  |

## Components

| Component           | Source                  | Purpose                       |
| ------------------- | ----------------------- | ----------------------------- |
| **Temporal Server** | `temporalio/auto-setup` | Core workflow engine          |
| **Temporal UI**     | `temporalio/ui`         | Workflow monitoring           |
| **Billing Service** | Custom (this repo)      | Stripe integration, invoicing |
| **Usage Collector** | Custom (this repo)      | Prometheus metrics → billing  |
| **Admin Portal**    | Custom (this repo)      | Customer billing dashboard    |

## OAuth/SSO

Enable authentication for your customers:

```bash
# See full guide
cat production/cloudflare-tunnel/OAUTH-SETUP.md
```

Supported providers:

- **Google OAuth** - Quick setup
- **Cloudflare Access** - Zero Trust (recommended for production)
- **Auth0** - Enterprise features
- **GitHub OAuth** - Developer-friendly

## Pricing Model

| Metric           | Price              |
| ---------------- | ------------------ |
| Actions          | $25-50 per million |
| Active Storage   | $0.042/GB-hour     |
| Retained Storage | $0.00105/GB-hour   |

See `billing-service/pricing.go` for implementation.

## One-Click Deployment

```bash
# Local deployment
./deploy.sh local

# OKE (Oracle Kubernetes) deployment
./deploy.sh oke

# Check status
./deploy.sh status
```

## Infrastructure as Code

| Component         | Tool           | Location                       |
| ----------------- | -------------- | ------------------------------ |
| **OKE Cluster**   | Terraform      | `production/terraform-oke/`    |
| **Budget/Alerts** | Terraform      | `production/terraform-budget/` |
| **K8s Resources** | Helm + YAML    | `production/oke-minimal/`      |
| **CI/CD**         | GitHub Actions | `.github/workflows/`           |

## Cost Controls

- **Budget**: $290 limit (with $10 buffer)
- **Alerts**: 80%, 95%, 100% thresholds
- **Autoscaling**: 1-3 replicas based on load
- **Node Pool**: 1 node minimum (scales to 3)

## Disaster Recovery

- **Daily backups**: PostgreSQL to OCI Object Storage
- **Retention**: 7 days
- **Restore**: `./deploy.sh restore [backup-file]`

## CI/CD Pipeline

1. **Test**: Unit tests + E2E tests
2. **Build**: Docker images to GHCR
3. **Deploy**: Helm upgrade to OKE
4. **Verify**: Health checks

## Upstream Dependencies

Uses official Temporal components:

- `temporalio/helm-charts` - Kubernetes deployment
- `temporalio/docker-builds` - Docker images
- `temporalio/temporal` - Server source
- `temporalio/ui` - Web UI
