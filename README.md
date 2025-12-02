# Temporal Cloud Offering

A monetizable Temporal-as-a-Service platform built on official Temporal components.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Customer Access                              │
├─────────────────────────────────────────────────────────────────────┤
│  Temporal UI (temporalio/ui)  │  Admin Portal (billing/usage)       │
│  http://localhost:8080        │  http://localhost:3000               │
└─────────────────────────────────────────────────────────────────────┘
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

## Components

| Component           | Source                  | Purpose                       |
| ------------------- | ----------------------- | ----------------------------- |
| **Temporal Server** | `temporalio/auto-setup` | Core workflow engine          |
| **Temporal UI**     | `temporalio/ui`         | Workflow monitoring           |
| **Billing Service** | Custom (this repo)      | Stripe integration, invoicing |
| **Usage Collector** | Custom (this repo)      | Prometheus metrics → billing  |
| **Admin Portal**    | Custom (this repo)      | Customer billing dashboard    |

## Quick Start

```bash
cd deploy
docker-compose up -d
```

## Services

- **Temporal UI**: http://localhost:8080
- **Admin Portal**: http://localhost:3000
- **Temporal gRPC**: localhost:7233
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3001

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
