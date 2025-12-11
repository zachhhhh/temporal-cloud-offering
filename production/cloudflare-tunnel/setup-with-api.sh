#!/bin/bash
# Setup Cloudflare Tunnel using API Key
# Usage: ./setup-with-api.sh <email> <api_key> <domain>

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 3 ]; then
    echo "Usage: $0 <cloudflare_email> <api_key> <domain>"
    echo ""
    echo "Example: $0 user@example.com abc123xyz example.com"
    exit 1
fi

CF_EMAIL="$1"
CF_API_KEY="$2"
DOMAIN="$3"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Cloudflare Tunnel Setup via API      ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get Zone ID
echo "Getting zone ID for $DOMAIN..."
ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "X-Auth-Key: $CF_API_KEY" \
    -H "Content-Type: application/json")

ZONE_ID=$(echo "$ZONE_RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['result'][0]['id'] if r['success'] and r['result'] else '')" 2>/dev/null)

if [ -z "$ZONE_ID" ]; then
    echo -e "${RED}Error: Could not find zone for $DOMAIN${NC}"
    echo "Response: $ZONE_RESPONSE"
    echo ""
    echo "Make sure:"
    echo "1. Domain is added to your Cloudflare account"
    echo "2. API key has Zone:Read permission"
    exit 1
fi

echo -e "${GREEN}Zone ID: $ZONE_ID${NC}"

# Get Account ID
ACCOUNT_ID=$(echo "$ZONE_RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['result'][0]['account']['id'] if r['success'] and r['result'] else '')" 2>/dev/null)
echo -e "${GREEN}Account ID: $ACCOUNT_ID${NC}"

# Create Tunnel
TUNNEL_NAME="temporal-${DOMAIN//./-}"
echo ""
echo "Creating tunnel: $TUNNEL_NAME..."

# Generate tunnel secret
TUNNEL_SECRET=$(openssl rand -base64 32)

TUNNEL_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "X-Auth-Key: $CF_API_KEY" \
    -H "Content-Type: application/json" \
    --data "{\"name\":\"$TUNNEL_NAME\",\"tunnel_secret\":\"$(echo -n "$TUNNEL_SECRET" | base64)\"}")

TUNNEL_ID=$(echo "$TUNNEL_RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['result']['id'] if r.get('success') else '')" 2>/dev/null)

if [ -z "$TUNNEL_ID" ]; then
    # Maybe tunnel already exists
    echo "Checking for existing tunnel..."
    TUNNELS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel?name=$TUNNEL_NAME" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json")
    
    TUNNEL_ID=$(echo "$TUNNELS_RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['result'][0]['id'] if r.get('success') and r.get('result') else '')" 2>/dev/null)
    
    if [ -z "$TUNNEL_ID" ]; then
        echo -e "${RED}Error: Could not create or find tunnel${NC}"
        echo "Response: $TUNNEL_RESPONSE"
        exit 1
    fi
    echo "Using existing tunnel: $TUNNEL_ID"
fi

echo -e "${GREEN}Tunnel ID: $TUNNEL_ID${NC}"

# Create DNS records
echo ""
echo "Creating DNS records..."

for subdomain in "app" "temporal" "api" "grafana"; do
    echo "  Creating $subdomain.$DOMAIN -> tunnel..."
    
    # Check if record exists
    EXISTING=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$subdomain.$DOMAIN&type=CNAME" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json")
    
    EXISTING_ID=$(echo "$EXISTING" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['result'][0]['id'] if r.get('success') and r.get('result') else '')" 2>/dev/null)
    
    if [ -n "$EXISTING_ID" ]; then
        # Update existing
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$EXISTING_ID" \
            -H "X-Auth-Email: $CF_EMAIL" \
            -H "X-Auth-Key: $CF_API_KEY" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"$subdomain\",\"content\":\"$TUNNEL_ID.cfargotunnel.com\",\"proxied\":true}" > /dev/null
    else
        # Create new
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
            -H "X-Auth-Email: $CF_EMAIL" \
            -H "X-Auth-Key: $CF_API_KEY" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"CNAME\",\"name\":\"$subdomain\",\"content\":\"$TUNNEL_ID.cfargotunnel.com\",\"proxied\":true}" > /dev/null
    fi
    echo -e "  ${GREEN}✓${NC} $subdomain.$DOMAIN"
done

# Get tunnel token for cloudflared
echo ""
echo "Getting tunnel token..."
TOKEN_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "X-Auth-Key: $CF_API_KEY" \
    -H "Content-Type: application/json")

TUNNEL_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['result'] if r.get('success') else '')" 2>/dev/null)

# Save configuration
mkdir -p "$SCRIPT_DIR/config"

cat > "$SCRIPT_DIR/.env" << EOF
# Cloudflare Tunnel Configuration
# Generated: $(date)

DOMAIN=$DOMAIN
ZONE_ID=$ZONE_ID
ACCOUNT_ID=$ACCOUNT_ID
TUNNEL_ID=$TUNNEL_ID
TUNNEL_NAME=$TUNNEL_NAME
TUNNEL_TOKEN=$TUNNEL_TOKEN

# Service URLs
APP_URL=https://app.$DOMAIN
TEMPORAL_URL=https://temporal.$DOMAIN
API_URL=https://api.$DOMAIN
GRAFANA_URL=https://grafana.$DOMAIN
EOF

# Create ingress config
cat > "$SCRIPT_DIR/config/config.yml" << EOF
tunnel: $TUNNEL_ID
credentials-file: $SCRIPT_DIR/config/credentials.json

ingress:
  - hostname: app.$DOMAIN
    service: http://localhost:3000
  - hostname: temporal.$DOMAIN
    service: http://localhost:8080
  - hostname: api.$DOMAIN
    service: http://localhost:8082
  - hostname: grafana.$DOMAIN
    service: http://localhost:3001
  - service: http_status:404
EOF

# Create credentials file
cat > "$SCRIPT_DIR/config/credentials.json" << EOF
{
  "AccountTag": "$ACCOUNT_ID",
  "TunnelID": "$TUNNEL_ID",
  "TunnelName": "$TUNNEL_NAME",
  "TunnelSecret": "$TUNNEL_SECRET"
}
EOF
chmod 600 "$SCRIPT_DIR/config/credentials.json"

# Create run script
cat > "$SCRIPT_DIR/run.sh" << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

# Option 1: Run with config file
cloudflared tunnel --config "\$SCRIPT_DIR/config/config.yml" run

# Option 2: Run with token (uncomment if config doesn't work)
# cloudflared tunnel run --token "$TUNNEL_TOKEN"
EOF
chmod +x "$SCRIPT_DIR/run.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!                      ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your services will be available at:"
echo ""
echo "  Admin Portal:  https://app.$DOMAIN"
echo "  Temporal UI:   https://temporal.$DOMAIN"
echo "  Billing API:   https://api.$DOMAIN"
echo "  Grafana:       https://grafana.$DOMAIN"
echo ""
echo "Start the tunnel:"
echo "  $SCRIPT_DIR/run.sh"
echo ""
echo "Or with token directly:"
echo "  cloudflared tunnel run --token $TUNNEL_TOKEN"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "NEXT: Enable SSO in Cloudflare Zero Trust Dashboard"
echo "  https://one.dash.cloudflare.com/"
echo ""
