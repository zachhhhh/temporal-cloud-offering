# Local Development + Cloudflare Tunnel (FREE)

Run everything on your Mac/PC and expose via Cloudflare Tunnel.

## Cost: $0

## Setup

### 1. Run Local Stack (Already Done!)

```bash
cd temporal-cloud-offering/deploy
docker-compose up -d
```

### 2. Install Cloudflare Tunnel

```bash
brew install cloudflared

# Login to Cloudflare
cloudflared tunnel login
```

### 3. Create Tunnel

```bash
# Create tunnel
cloudflared tunnel create temporal-cloud

# This creates credentials at ~/.cloudflared/<TUNNEL_ID>.json
```

### 4. Configure Tunnel

```yaml
# ~/.cloudflared/config.yml
tunnel: <TUNNEL_ID>
credentials-file: /Users/you/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: cloud.yourdomain.com
    service: http://localhost:3000
  - hostname: temporal.yourdomain.com
    service: http://localhost:8080
  - hostname: api.yourdomain.com
    service: http://localhost:8082
  - service: http_status:404
```

### 5. Add DNS Records

```bash
# In Cloudflare Dashboard or via CLI:
cloudflared tunnel route dns temporal-cloud cloud.yourdomain.com
cloudflared tunnel route dns temporal-cloud temporal.yourdomain.com
cloudflared tunnel route dns temporal-cloud api.yourdomain.com
```

### 6. Run Tunnel

```bash
# Run in background
cloudflared tunnel run temporal-cloud

# Or as a service
sudo cloudflared service install
```

## Pros

- Completely FREE
- Full control
- Easy debugging
- No cold starts

## Cons

- Your computer must be running
- Depends on your internet connection
- Not suitable for production with real customers

## Best For

- Demos
- Development
- Testing with beta users
- Validating product-market fit
