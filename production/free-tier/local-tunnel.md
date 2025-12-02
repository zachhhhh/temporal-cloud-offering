# Local Development + Cloudflare Tunnel (FREE)

Run everything on your Mac/PC and expose via Cloudflare Tunnel with OAuth/SSO.

## Cost: $0

## Quick Start (Automated)

```bash
# 1. Start local services
cd temporal-cloud-offering/deploy
docker-compose up -d

# 2. Run the automated setup script
cd ../production/cloudflare-tunnel
chmod +x setup-tunnel.sh
./setup-tunnel.sh

# 3. Start the tunnel
./run-tunnel.sh
```

That's it! Your services are now accessible at:

- **Admin Portal**: https://app.YOUR_DOMAIN
- **Temporal UI**: https://temporal.YOUR_DOMAIN
- **Billing API**: https://api.YOUR_DOMAIN
- **Grafana**: https://grafana.YOUR_DOMAIN

---

## Manual Setup (Step by Step)

### 1. Run Local Stack

```bash
cd temporal-cloud-offering/deploy
docker-compose up -d
```

### 2. Install Cloudflare Tunnel

```bash
# macOS
brew install cloudflared

# Linux
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

### 3. Login to Cloudflare

```bash
cloudflared tunnel login
# Browser opens - select your domain
```

### 4. Create Tunnel

```bash
cloudflared tunnel create temporal-cloud
# Note the Tunnel ID output
```

### 5. Configure Tunnel

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: YOUR_TUNNEL_ID
credentials-file: /Users/YOUR_USER/.cloudflared/YOUR_TUNNEL_ID.json

ingress:
  - hostname: app.yourdomain.com
    service: http://localhost:3000
  - hostname: temporal.yourdomain.com
    service: http://localhost:8080
  - hostname: api.yourdomain.com
    service: http://localhost:8082
  - hostname: grafana.yourdomain.com
    service: http://localhost:3001
  - service: http_status:404
```

### 6. Add DNS Records

```bash
cloudflared tunnel route dns temporal-cloud app.yourdomain.com
cloudflared tunnel route dns temporal-cloud temporal.yourdomain.com
cloudflared tunnel route dns temporal-cloud api.yourdomain.com
cloudflared tunnel route dns temporal-cloud grafana.yourdomain.com
```

### 7. Run Tunnel

```bash
cloudflared tunnel run temporal-cloud
```

---

## Adding OAuth/SSO

See [../cloudflare-tunnel/OAUTH-SETUP.md](../cloudflare-tunnel/OAUTH-SETUP.md) for:

- Google OAuth
- Cloudflare Access (Zero Trust)
- Auth0
- GitHub OAuth

### Quick Google OAuth

1. Create credentials at [Google Cloud Console](https://console.cloud.google.com/)
2. Add callback: `https://temporal.yourdomain.com/sso/callback`
3. Set environment variables and restart

---

## Run as Background Service

### macOS

```bash
# Install as LaunchAgent
cp production/cloudflare-tunnel/config/com.cloudflare.temporal-tunnel.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.cloudflare.temporal-tunnel.plist

# Check status
launchctl list | grep cloudflare
```

### Linux

```bash
sudo cp production/cloudflare-tunnel/config/cloudflared-temporal.service /etc/systemd/system/
sudo systemctl enable cloudflared-temporal
sudo systemctl start cloudflared-temporal
sudo systemctl status cloudflared-temporal
```

---

## Pros

- **Completely FREE** - No hosting costs
- **Real domain with SSL** - Professional URLs
- **OAuth/SSO ready** - Enterprise authentication
- **Full control** - Debug locally
- **No cold starts** - Always running
- **DDoS protection** - Cloudflare's network

## Cons

- Your computer must be running
- Depends on your internet connection
- Not suitable for high-availability production

## Best For

- Demos and sales calls
- Development and testing
- Beta users and early adopters
- Validating product-market fit
- Small teams (< 10 users)

---

## Troubleshooting

### Tunnel won't start

```bash
# Check credentials exist
ls ~/.cloudflared/

# Re-login if needed
cloudflared tunnel login
```

### DNS not resolving

```bash
# Verify DNS
dig app.yourdomain.com

# Check tunnel routes
cloudflared tunnel route ip show
```

### Services not accessible

```bash
# Check services are running
docker ps

# Test locally first
curl http://localhost:3000
curl http://localhost:8080
```

---

## Next Steps

1. **Add OAuth** - See [OAUTH-SETUP.md](../cloudflare-tunnel/OAUTH-SETUP.md)
2. **Enable Cloudflare Access** - Zero Trust security
3. **Configure workers** - mTLS for Temporal workers
4. **Scale up** - Move to [Oracle Cloud Free Tier](./oracle-cloud.md) or [Hetzner](../hetzner/)
