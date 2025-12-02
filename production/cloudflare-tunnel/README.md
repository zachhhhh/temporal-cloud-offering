# Production Deployment with Cloudflare Tunnel

Expose Temporal Cloud to customers with real domain, SSL, and SSO - **FREE**.

## What You Get

- **Free SSL** - Automatic HTTPS certificates
- **Free SSO** - Cloudflare Access (Google, GitHub, SAML, email OTP)
- **DDoS protection** - Cloudflare's global network
- **No port forwarding** - Works behind NAT/firewalls
- **Real domain** - Professional URLs for customers

## Architecture

```
Customer Browser
       │
       ▼
┌──────────────────────────────────────┐
│     Cloudflare Edge (Global CDN)     │
│  ┌────────────────────────────────┐  │
│  │   Cloudflare Access (SSO)      │  │
│  │   - Google OAuth               │  │
│  │   - GitHub OAuth               │  │
│  │   - Email OTP                  │  │
│  │   - SAML/Okta                  │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
       │ (Encrypted Tunnel)
       ▼
┌──────────────────────────────────────┐
│     Your Machine (Docker Compose)    │
│  ├── Admin Portal (:3000)            │
│  ├── Temporal UI (:8080)             │
│  ├── Billing API (:8082)             │
│  └── Grafana (:3001)                 │
└──────────────────────────────────────┘
```

## Quick Demo (No Login Required)

Test with temporary URLs that change on restart:

```bash
./quick-tunnel.sh
```

## Production Setup (Permanent URLs + SSO)

### Prerequisites

1. **Cloudflare account** (free) - [Sign up](https://dash.cloudflare.com/sign-up)
2. **Domain** in Cloudflare - Add existing or get free from [Freenom](https://freenom.com)
3. **Docker services running** - `cd deploy && docker-compose up -d`

### Setup

```bash
./production-setup.sh
```

This will:

1. Login to Cloudflare (opens browser)
2. Create permanent tunnel
3. Configure DNS records
4. Generate run script

### Start Tunnel

```bash
./run.sh
```

### Enable SSO (Cloudflare Access)

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com/)
2. **Access** → **Applications** → **Add Application**
3. Select **Self-hosted**
4. Configure:
   - **Name**: Temporal UI
   - **Domain**: temporal.yourdomain.com
   - **Session Duration**: 24h
5. Add policy:
   - **Allow** emails ending in `@yourcompany.com`
   - Or specific emails: `user@gmail.com`
6. Repeat for `app.yourdomain.com`, `grafana.yourdomain.com`

### Your URLs

- **Admin Portal**: https://app.YOUR_DOMAIN
- **Temporal UI**: https://temporal.YOUR_DOMAIN
- **Billing API**: https://api.YOUR_DOMAIN
- **Grafana**: https://grafana.YOUR_DOMAIN

## Configuration Files

| File                            | Purpose                       |
| ------------------------------- | ----------------------------- |
| `setup-tunnel.sh`               | Initial tunnel setup          |
| `run-tunnel.sh`                 | Start the tunnel              |
| `.env`                          | Environment variables         |
| `config/cloudflared-config.yml` | Tunnel routing config         |
| `docker-compose.tunnel.yaml`    | Full stack with tunnel        |
| `OAUTH-SETUP.md`                | OAuth/SSO configuration guide |

## Adding OAuth/SSO

See [OAUTH-SETUP.md](./OAUTH-SETUP.md) for detailed instructions on:

- Google OAuth
- Cloudflare Access (Zero Trust)
- Auth0
- GitHub OAuth

### Quick OAuth Setup (Google)

1. Create OAuth credentials at [Google Cloud Console](https://console.cloud.google.com/)
2. Add callback URL: `https://temporal.YOUR_DOMAIN/sso/callback`
3. Update `.env`:
   ```bash
   GOOGLE_CLIENT_ID=your-client-id
   GOOGLE_CLIENT_SECRET=your-client-secret
   AUTH_ENABLED=true
   ```
4. Restart services

## Running as a Service

### macOS

```bash
cp config/com.cloudflare.temporal-tunnel.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.cloudflare.temporal-tunnel.plist
```

### Linux

```bash
sudo cp config/cloudflared-temporal.service /etc/systemd/system/
sudo systemctl enable cloudflared-temporal
sudo systemctl start cloudflared-temporal
```

## Troubleshooting

### Tunnel won't connect

```bash
# Check tunnel status
cloudflared tunnel info temporal-cloud-YOUR_DOMAIN

# View logs
cloudflared tunnel --config config/cloudflared-config.yml run --loglevel debug
```

### DNS not resolving

```bash
# Verify DNS records
dig app.YOUR_DOMAIN

# Re-add DNS route
cloudflared tunnel route dns YOUR_TUNNEL_NAME app.YOUR_DOMAIN
```

### Services not accessible

```bash
# Check services are running
docker ps

# Test local connectivity
curl http://localhost:3000
curl http://localhost:8080
```

## Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────┐
│         Cloudflare Edge             │
│  (SSL, DDoS, Access Policies)       │
└─────────────────────────────────────┘
    │
    ▼ (Encrypted tunnel)
┌─────────────────────────────────────┐
│         cloudflared                 │
│  (Running on your machine)          │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│         Your Services               │
│  ├── Admin Portal (:3000)           │
│  ├── Temporal UI (:8080)            │
│  ├── Billing API (:8082)            │
│  └── Grafana (:3001)                │
└─────────────────────────────────────┘
```

## Cost

- **Cloudflare Tunnel**: FREE
- **Cloudflare Access** (50 users): FREE
- **SSL Certificates**: FREE (automatic)
- **DDoS Protection**: FREE (basic)

## Security Notes

1. **Never expose** Temporal gRPC (7233) directly - use mTLS for workers
2. **Enable Cloudflare Access** for production deployments
3. **Rotate secrets** regularly
4. **Monitor** access logs in Cloudflare dashboard

## Next Steps

1. [Configure OAuth/SSO](./OAUTH-SETUP.md)
2. [Set up Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/applications/)
3. [Configure worker mTLS](../../docs/worker-mtls.md)
