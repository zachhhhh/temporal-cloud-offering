#!/bin/bash
# Production Setup for Temporal Cloud Offering
# Creates: Cloudflare Tunnel + Cloudflare Access (SSO) + Free Domain
#
# Prerequisites:
# - Cloudflare account (free)
# - Domain in Cloudflare (can be free from Freenom, or use existing)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLOUDFLARED_DIR="$HOME/.cloudflared"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Temporal Cloud - Production Setup                      ║${NC}"
echo -e "${BLUE}║     Cloudflare Tunnel + SSO (Zero Trust)                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check cloudflared
if ! command -v cloudflared &> /dev/null; then
    log_error "cloudflared not installed"
    echo "Install with: brew install cloudflared"
    exit 1
fi

# Check if logged in
if [ ! -f "$CLOUDFLARED_DIR/cert.pem" ]; then
    echo ""
    log_warn "Not logged into Cloudflare"
    echo ""
    echo "You need to login to Cloudflare to create a permanent tunnel."
    echo "This will open a browser window."
    echo ""
    read -p "Press Enter to login to Cloudflare..."
    cloudflared tunnel login
    echo ""
    log_info "Login successful!"
fi

# Get available domains
echo ""
log_info "Fetching your Cloudflare domains..."
echo ""

# List tunnels to verify auth works
cloudflared tunnel list > /dev/null 2>&1 || {
    log_error "Failed to connect to Cloudflare. Please re-login."
    rm -f "$CLOUDFLARED_DIR/cert.pem"
    exit 1
}

# Get domain from user
echo "Enter the domain you added to Cloudflare."
echo "Examples: yourdomain.com, mycompany.io"
echo ""
read -p "Domain: " DOMAIN

if [ -z "$DOMAIN" ]; then
    log_error "Domain is required"
    exit 1
fi

# Tunnel name
TUNNEL_NAME="temporal-${DOMAIN//./-}"

# Check if tunnel exists
EXISTING_TUNNEL=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME" | awk '{print $1}' || true)

if [ -n "$EXISTING_TUNNEL" ]; then
    log_info "Using existing tunnel: $TUNNEL_NAME ($EXISTING_TUNNEL)"
    TUNNEL_ID="$EXISTING_TUNNEL"
else
    log_info "Creating tunnel: $TUNNEL_NAME"
    cloudflared tunnel create "$TUNNEL_NAME"
    TUNNEL_ID=$(cloudflared tunnel list | grep -w "$TUNNEL_NAME" | awk '{print $1}')
fi

log_info "Tunnel ID: $TUNNEL_ID"

# Create config directory
mkdir -p "$SCRIPT_DIR/config"

# Create cloudflared config
cat > "$SCRIPT_DIR/config/config.yml" << EOF
# Cloudflare Tunnel Configuration
# Domain: $DOMAIN
# Generated: $(date)

tunnel: $TUNNEL_ID
credentials-file: $CLOUDFLARED_DIR/$TUNNEL_ID.json

ingress:
  # Admin Portal (Customer Dashboard)
  - hostname: app.$DOMAIN
    service: http://localhost:3000

  # Temporal UI (Workflow Monitoring)  
  - hostname: temporal.$DOMAIN
    service: http://localhost:8080

  # Billing API
  - hostname: api.$DOMAIN
    service: http://localhost:8082

  # Grafana (Metrics)
  - hostname: grafana.$DOMAIN
    service: http://localhost:3001

  # Catch-all
  - service: http_status:404
EOF

log_info "Created tunnel config"

# Create DNS records
echo ""
log_info "Creating DNS records..."

for subdomain in "app" "temporal" "api" "grafana"; do
    log_info "  → $subdomain.$DOMAIN"
    cloudflared tunnel route dns "$TUNNEL_NAME" "$subdomain.$DOMAIN" 2>/dev/null || true
done

# Create run script
cat > "$SCRIPT_DIR/run.sh" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Starting Cloudflare Tunnel..."
cloudflared tunnel --config "$SCRIPT_DIR/config/config.yml" run
EOF
chmod +x "$SCRIPT_DIR/run.sh"

# Create .env
cat > "$SCRIPT_DIR/.env" << EOF
# Production Configuration
# Generated: $(date)

DOMAIN=$DOMAIN
TUNNEL_ID=$TUNNEL_ID
TUNNEL_NAME=$TUNNEL_NAME

# URLs
APP_URL=https://app.$DOMAIN
TEMPORAL_URL=https://temporal.$DOMAIN
API_URL=https://api.$DOMAIN
GRAFANA_URL=https://grafana.$DOMAIN
EOF

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Setup Complete!                                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Your production URLs:"
echo ""
echo "  Admin Portal:  https://app.$DOMAIN"
echo "  Temporal UI:   https://temporal.$DOMAIN"
echo "  Billing API:   https://api.$DOMAIN"
echo "  Grafana:       https://grafana.$DOMAIN"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Start the tunnel:"
echo "   ${GREEN}$SCRIPT_DIR/run.sh${NC}"
echo ""
echo "2. Enable SSO (Cloudflare Access):"
echo "   a. Go to: https://one.dash.cloudflare.com/"
echo "   b. Navigate to: Access → Applications → Add Application"
echo "   c. Add each subdomain (app.$DOMAIN, temporal.$DOMAIN, etc.)"
echo "   d. Configure identity providers (Google, GitHub, etc.)"
echo ""
echo "3. (Optional) Run as background service:"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   cloudflared service install"
    echo "   sudo launchctl start com.cloudflare.cloudflared"
else
    echo "   sudo cloudflared service install"
    echo "   sudo systemctl start cloudflared"
fi
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "For SSO setup guide, see: $SCRIPT_DIR/OAUTH-SETUP.md"
echo ""
