# Marketing Site Deployment Guide

## Overview

The Temporal Cloud Marketing Site is a SvelteKit application that can be deployed to:

1. **Cloudflare Pages** (default) - For global CDN distribution
2. **Oracle Cloud (OCI)** - For self-hosted Kubernetes deployment

## Prerequisites

### For Cloudflare Pages

- Cloudflare account with Pages enabled
- Wrangler CLI installed (`npm install -g wrangler`)

### For Oracle Cloud (OCI)

- OCI account with Always Free tier resources
- Terraform >= 1.0
- kubectl
- Docker
- SSH key pair for instance access

## Build Configuration

The build adapter is controlled by the `BUILD_ADAPTER` environment variable:

```bash
# For Cloudflare Pages (default)
npm run build

# For Node.js/Docker (OCI deployment)
BUILD_ADAPTER=node npm run build
```

## Cloudflare Pages Deployment

```bash
# Login to Cloudflare
wrangler login

# Deploy to Pages
wrangler pages deploy build --project-name=temporal-cloud-marketing
```

### Environment Variables (Cloudflare Dashboard)

- `GOOGLE_CLIENT_ID` - Google OAuth client ID
- `GOOGLE_CLIENT_SECRET` - Google OAuth client secret
- `GOOGLE_REDIRECT_URI` - OAuth callback URL
- `RESEND_API_KEY` - Resend API key for magic link emails

## Oracle Cloud (OCI) Deployment

### 1. Setup OCI Credentials

Create or update your OCI API key:

```bash
# Generate new API key (if needed)
mkdir -p ~/.oci
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
chmod 600 ~/.oci/oci_api_key.pem
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem

# Get fingerprint
openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c
```

Upload the public key to OCI Console:

1. Go to Identity > Users > Your User > API Keys
2. Click "Add API Key"
3. Paste the contents of `~/.oci/oci_api_key_public.pem`

Update `~/.oci/config`:

```ini
[DEFAULT]
user=ocid1.user.oc1..your-user-ocid
fingerprint=your:key:fingerprint
tenancy=ocid1.tenancy.oc1..your-tenancy-ocid
region=ap-singapore-1
key_file=/Users/your-username/.oci/oci_api_key.pem
```

### 2. Deploy Infrastructure with Terraform

```bash
cd production/terraform-oci

# Update terraform.tfvars with your values
# - tenancy_ocid
# - user_ocid
# - fingerprint
# - compartment_ocid
# - availability_domain
# - os_image_id
# - my_public_ip_cidr
# - certmanager_email_address

# Initialize and apply
terraform init
terraform plan
terraform apply
```

### 3. Get Kubeconfig

After Terraform completes:

```bash
# Get the server IP
terraform output public_lb_ip

# SSH to server and get kubeconfig
scp -i ~/.ssh/oracle_temporal ubuntu@<SERVER_IP>:/etc/rancher/k3s/k3s.yaml ~/.kube/config-oci

# Update the server address in kubeconfig
sed -i '' 's/127.0.0.1/<PUBLIC_LB_IP>/g' ~/.kube/config-oci

# Test connection
kubectl --kubeconfig=~/.kube/config-oci get nodes
```

### 4. Build and Deploy Marketing Site

```bash
cd marketing-site

# Build Docker image
docker build -t ghcr.io/temporalio/temporal-cloud-marketing:latest .

# Push to registry (or use local registry)
docker push ghcr.io/temporalio/temporal-cloud-marketing:latest

# Deploy to K8s
kubectl --kubeconfig=~/.kube/config-oci apply -f ../production/k8s-manifests/09-marketing-site.yaml

# Check status
kubectl --kubeconfig=~/.kube/config-oci -n temporal-cloud get pods -l app=marketing-site
```

Or use the deployment script:

```bash
./deploy-to-oci.sh all
```

## Production Checklist

### Security

- [ ] Configure Google OAuth credentials
- [ ] Set up Resend API key for magic link emails
- [ ] Enable HTTPS with valid SSL certificates
- [ ] Configure CORS for API endpoints
- [ ] Set secure cookie options (httpOnly, secure, sameSite)

### Performance

- [ ] Enable gzip/brotli compression
- [ ] Configure CDN caching headers
- [ ] Optimize images and assets
- [ ] Enable HTTP/2

### Monitoring

- [ ] Set up health check endpoints
- [ ] Configure logging
- [ ] Set up alerts for downtime

### DNS

- [ ] Point domain to load balancer IP
- [ ] Configure SSL certificate for custom domain
- [ ] Set up www redirect

## Environment Variables

| Variable               | Description                          | Required           |
| ---------------------- | ------------------------------------ | ------------------ |
| `NODE_ENV`             | Environment (production/development) | Yes                |
| `PORT`                 | Server port (default: 3002)          | No                 |
| `ORIGIN`               | Site origin URL for SvelteKit        | Yes (Node adapter) |
| `VITE_TEMPORAL_UI`     | Temporal UI URL                      | No                 |
| `VITE_BILLING_API`     | Billing API URL                      | No                 |
| `GOOGLE_CLIENT_ID`     | Google OAuth client ID               | For OAuth          |
| `GOOGLE_CLIENT_SECRET` | Google OAuth secret                  | For OAuth          |
| `RESEND_API_KEY`       | Resend API key                       | For magic links    |

## Troubleshooting

### OCI Authentication Failed

```
401-NotAuthenticated: The required information to complete authentication was not provided
```

Solution:

1. Verify API key exists in OCI Console (Identity > Users > API Keys)
2. Check fingerprint matches: `openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c`
3. Regenerate API key if needed

### Kubernetes Connection Timeout

```
dial tcp <IP>:6443: i/o timeout
```

Solution:

1. Verify K3s cluster is running
2. Check security group allows port 6443
3. Verify kubeconfig has correct server IP

### Build Fails

```
Error: Cannot find module '@sveltejs/adapter-node'
```

Solution:

```bash
npm install
```
