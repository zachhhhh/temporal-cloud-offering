# Production Setup Guide

Deploy Temporal Cloud Offering to production for **$0/month**.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Cloudflare (Free Tier)                            │
├─────────────────────────────────────────────────────────────────────┤
│  Admin Portal (Pages)  │  Cloudflare Access (SSO)  │  DNS + SSL     │
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

## Prerequisites

- Cloudflare account (free)
- Oracle Cloud account (free tier)
- Stripe account (for payments)
- Domain name (~$5-10/year on Cloudflare)

## Step 1: Deploy Admin Portal (Cloudflare Pages)

```bash
cd admin-portal
npm install
npm run build
wrangler pages deploy out --project-name=temporal-admin-portal
```

**Live URL:** https://temporal-admin-portal.pages.dev

## Step 2: Set Up Cloudflare Access (SSO)

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Access → Applications → Add Application
3. Select "Self-hosted"
4. Configure:
   - Application name: `Temporal Admin`
   - Domain: `temporal-admin-portal.pages.dev`
5. Add identity providers:
   - Google (one-click setup)
   - GitHub
   - Microsoft/Azure AD

## Step 3: Deploy Backend (Oracle Cloud)

### Create Oracle Cloud Account

1. Sign up at https://cloud.oracle.com
2. Free tier includes:
   - 4 ARM cores + 24GB RAM
   - 200GB storage
   - 10TB outbound/month

### Deploy K3s Cluster

```bash
cd production/terraform-oci

# Configure credentials
cp terraform.tfvars.example terraform.tfvars
# Edit with your Oracle Cloud credentials

terraform init
terraform apply
```

### Deploy Services

```bash
# Get kubeconfig
scp ubuntu@<server-ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Deploy Temporal + Billing
cd production/k8s
kubectl apply -f .
```

## Step 4: Configure Cloudflare Tunnel

Connect Oracle Cloud to Cloudflare:

```bash
cd production/cloudflare-tunnel
./setup-with-api.sh your@email.com YOUR_API_KEY your-domain.com
```

Creates:

- `temporal.your-domain.com` → Temporal UI
- `api.your-domain.com` → Billing API

## Step 5: Configure Stripe

1. Create products in [Stripe Dashboard](https://dashboard.stripe.com/products):

   - Essential: $100/month
   - Business: $500/month
   - Enterprise: Custom

2. Set up webhook:

   - Endpoint: `https://api.your-domain.com/stripe/webhook`
   - Events: `checkout.session.completed`, `customer.subscription.*`

3. Add secrets to billing-service:
   ```bash
   kubectl create secret generic stripe-secrets \
     --from-literal=STRIPE_SECRET_KEY=sk_live_xxx \
     --from-literal=STRIPE_WEBHOOK_SECRET=whsec_xxx
   ```

## Step 6: Configure Admin Portal

Set environment variables in Cloudflare Pages dashboard:

| Variable                            | Value                              |
| ----------------------------------- | ---------------------------------- |
| `NEXT_PUBLIC_BILLING_API`           | `https://api.your-domain.com`      |
| `NEXT_PUBLIC_TEMPORAL_UI`           | `https://temporal.your-domain.com` |
| `NEXT_PUBLIC_CF_ACCESS_TEAM_DOMAIN` | `your-team.cloudflareaccess.com`   |

## Verify Deployment

```bash
# Check Temporal UI
curl https://temporal.your-domain.com

# Check Billing API
curl https://api.your-domain.com/health

# Admin Portal
open https://temporal-admin-portal.pages.dev
```

## Security Checklist

- [ ] Cloudflare Access configured with identity provider
- [ ] Stripe webhook secret configured
- [ ] Database password is strong
- [ ] Cloudflare WAF enabled
- [ ] Rate limiting configured

## Cost Summary

| Service           | Cost                |
| ----------------- | ------------------- |
| Cloudflare Pages  | $0                  |
| Cloudflare Access | $0 (up to 50 users) |
| Cloudflare Tunnel | $0                  |
| Oracle Cloud      | $0 (free tier)      |
| Domain            | ~$5-10/year         |
| **Total**         | **~$5-10/year**     |

## Troubleshooting

### Tunnel not connecting

```bash
cloudflared tunnel info
journalctl -u cloudflared -f
```

### SSO not working

- Verify Cloudflare Access application domain
- Check identity provider configuration

### Billing API errors

```bash
kubectl logs -l app=billing-service -f
```
