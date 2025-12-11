# Temporal Cloud Offering

A monetizable Temporal-as-a-Service platform built on official Temporal components.

## Quick Start

```bash
# 1. Start backend services locally
cd production && ./deploy-all.sh

# 2. Admin Portal is live at:
#    https://temporal-admin-portal.pages.dev
```

**Local URLs:**

- Admin Portal: http://localhost:3000
- Temporal UI: http://localhost:8080
- Billing API: http://localhost:8082

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Cloudflare (Free Tier)                            │
├─────────────────────────────────────────────────────────────────────┤
│  Admin Portal          │  Cloudflare Access (SSO)                   │
│  (Cloudflare Pages)    │  Google/GitHub/Microsoft login             │
│  Static Site - FREE    │  Zero Trust - FREE                         │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                          Cloudflare Tunnel
                                   │
┌─────────────────────────────────────────────────────────────────────┐
│              Oracle Cloud Free Tier ($0/month)                       │
├──────────────────┬──────────────────┬───────────────────────────────┤
│  Billing Service │  Temporal Server │  PostgreSQL                   │
│  (Go + Stripe)   │  + Temporal UI   │  + Elasticsearch              │
└──────────────────┴──────────────────┴───────────────────────────────┘
```

## Deployment

| Component        | Hosting           | Cost |
| ---------------- | ----------------- | ---- |
| **Admin Portal** | Cloudflare Pages  | $0   |
| **Backend**      | Oracle Cloud K3s  | $0   |
| **Auth (SSO)**   | Cloudflare Access | $0   |
| **DNS + SSL**    | Cloudflare        | $0   |

### Deploy Website (includes Dashboard)

```bash
cd marketing-site
npm run build
wrangler pages deploy build --project-name=temporal-cloud
```

### Deploy Backend (Oracle Cloud)

```bash
cd production/terraform-oci
terraform apply

# Then deploy services
cd ../k8s
kubectl apply -f .
```

## Components

| Component           | Source                  | Purpose                       |
| ------------------- | ----------------------- | ----------------------------- |
| **Temporal Server** | `temporalio/auto-setup` | Core workflow engine          |
| **Temporal UI**     | `temporalio/ui`         | Workflow monitoring           |
| **Billing Service** | Custom (Go)             | Stripe integration, invoicing |
| **Marketing Site**  | Custom (SvelteKit)      | Landing + Dashboard (static)  |

## Authentication

Built-in authentication with:

- **Google OAuth** - Sign in with Google
- **Microsoft OAuth** - Sign in with Microsoft
- **Email** - Magic link / email sign-in

Users must sign in before accessing the dashboard. Auth state is stored in browser localStorage.

## Pricing Model (matching temporal.io)

| Metric           | Price                                    |
| ---------------- | ---------------------------------------- |
| Actions          | $50/M (first 5M), $45/M (next 5M), $40/M |
| Active Storage   | $0.042/GB-hour (~$1/GB-day)              |
| Retained Storage | $0.00105/GB-hour (~$0.025/GB-day)        |

| Plan             | Price   | Actions Included | Storage |
| ---------------- | ------- | ---------------- | ------- |
| Essential        | $200/mo | 5M               | 1 GB    |
| Business         | $800/mo | 20M              | 5 GB    |
| Enterprise       | Custom  | Custom           | Custom  |
| Mission Critical | Custom  | Unlimited        | Custom  |

## Infrastructure

| Component          | Tool      | Location                    |
| ------------------ | --------- | --------------------------- |
| **K3s Cluster**    | Terraform | `production/terraform-oci/` |
| **K8s Resources**  | kubectl   | `production/k8s/`           |
| **Marketing Site** | Wrangler  | `marketing-site/`           |

## Upstream Dependencies

Uses official Temporal components:

- `temporalio/auto-setup` - Server with auto-setup
- `temporalio/ui` - Web UI
- `temporalio/helm-charts` - Kubernetes deployment
