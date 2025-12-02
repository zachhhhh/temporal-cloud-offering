#!/bin/bash
# Cloudflare Tunnel Setup for Temporal Cloud Offering
# This script sets up a Cloudflare Tunnel with OAuth/SSO protection

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLOUDFLARED_DIR="$HOME/.cloudflared"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Cloudflare Tunnel Setup              ${NC}"
echo -e "${BLUE}  Temporal Cloud Offering              ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    log_error "cloudflared not installed. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install cloudflared
    else
        curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared.deb
        rm cloudflared.deb
    fi
fi

log_info "cloudflared version: $(cloudflared --version)"

# Check if already logged in
if [ ! -f "$CLOUDFLARED_DIR/cert.pem" ]; then
    log_info "Logging into Cloudflare..."
    echo ""
    echo "A browser window will open. Please log in to your Cloudflare account"
    echo "and select the domain you want to use."
    echo ""
    read -p "Press Enter to continue..."
    cloudflared tunnel login
fi

log_info "Cloudflare authentication found."

# Get domain from user
echo ""
read -p "Enter your domain (e.g., temporalcloud.dev): " DOMAIN
if [ -z "$DOMAIN" ]; then
    log_error "Domain is required"
    exit 1
fi

# Tunnel name
TUNNEL_NAME="temporal-cloud-${DOMAIN//./-}"
log_info "Tunnel name: $TUNNEL_NAME"

# Check if tunnel exists
EXISTING_TUNNEL=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}' || true)

if [ -n "$EXISTING_TUNNEL" ]; then
    log_info "Tunnel already exists: $EXISTING_TUNNEL"
    TUNNEL_ID="$EXISTING_TUNNEL"
else
    log_info "Creating new tunnel..."
    cloudflared tunnel create "$TUNNEL_NAME"
    TUNNEL_ID=$(cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}')
fi

log_info "Tunnel ID: $TUNNEL_ID"

# Create config directory
mkdir -p "$SCRIPT_DIR/config"

# Create cloudflared config
cat > "$SCRIPT_DIR/config/cloudflared-config.yml" << EOF
# Cloudflare Tunnel Configuration
# Generated for: $DOMAIN

tunnel: $TUNNEL_ID
credentials-file: $CLOUDFLARED_DIR/$TUNNEL_ID.json

# Ingress rules - route traffic to local services
ingress:
  # Admin Portal (Customer Dashboard)
  - hostname: app.$DOMAIN
    service: http://localhost:3000
    originRequest:
      noTLSVerify: true

  # Temporal UI (Workflow Monitoring)
  - hostname: temporal.$DOMAIN
    service: http://localhost:8080
    originRequest:
      noTLSVerify: true

  # Billing API
  - hostname: api.$DOMAIN
    service: http://localhost:8082
    originRequest:
      noTLSVerify: true

  # Grafana (Metrics Dashboard)
  - hostname: grafana.$DOMAIN
    service: http://localhost:3001
    originRequest:
      noTLSVerify: true

  # Catch-all (required)
  - service: http_status:404
EOF

log_info "Created cloudflared config at $SCRIPT_DIR/config/cloudflared-config.yml"

# Create DNS records
echo ""
log_info "Setting up DNS records..."

for subdomain in "app" "temporal" "api" "grafana"; do
    log_info "Creating DNS record: $subdomain.$DOMAIN"
    cloudflared tunnel route dns "$TUNNEL_NAME" "$subdomain.$DOMAIN" 2>/dev/null || \
        log_warn "DNS record for $subdomain.$DOMAIN may already exist"
done

# Create .env file for the project
cat > "$SCRIPT_DIR/.env" << EOF
# Cloudflare Tunnel Configuration
# Generated: $(date)

DOMAIN=$DOMAIN
TUNNEL_ID=$TUNNEL_ID
TUNNEL_NAME=$TUNNEL_NAME

# Service URLs (for OAuth callbacks)
APP_URL=https://app.$DOMAIN
TEMPORAL_UI_URL=https://temporal.$DOMAIN
API_URL=https://api.$DOMAIN
GRAFANA_URL=https://grafana.$DOMAIN

# OAuth/SSO Configuration (fill these in)
# Google OAuth
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# Or Auth0
AUTH0_DOMAIN=
AUTH0_CLIENT_ID=
AUTH0_CLIENT_SECRET=

# Or GitHub
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
EOF

log_info "Created .env file at $SCRIPT_DIR/.env"

# Create run script
cat > "$SCRIPT_DIR/run-tunnel.sh" << 'RUNEOF'
#!/bin/bash
# Run Cloudflare Tunnel

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/cloudflared-config.yml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found. Run setup-tunnel.sh first."
    exit 1
fi

echo "Starting Cloudflare Tunnel..."
echo "Press Ctrl+C to stop"
echo ""

cloudflared tunnel --config "$CONFIG_FILE" run
RUNEOF
chmod +x "$SCRIPT_DIR/run-tunnel.sh"

# Create systemd/launchd service files
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS LaunchAgent
    cat > "$SCRIPT_DIR/config/com.cloudflare.temporal-tunnel.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cloudflare.temporal-tunnel</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/cloudflared</string>
        <string>tunnel</string>
        <string>--config</string>
        <string>$SCRIPT_DIR/config/cloudflared-config.yml</string>
        <string>run</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/cloudflared-temporal.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/cloudflared-temporal.error.log</string>
</dict>
</plist>
EOF
    log_info "Created LaunchAgent plist"
else
    # Linux systemd
    cat > "$SCRIPT_DIR/config/cloudflared-temporal.service" << EOF
[Unit]
Description=Cloudflare Tunnel for Temporal Cloud
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --config $SCRIPT_DIR/config/cloudflared-config.yml run
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    log_info "Created systemd service file"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!                      ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your services will be available at:"
echo "  - Admin Portal:  https://app.$DOMAIN"
echo "  - Temporal UI:   https://temporal.$DOMAIN"
echo "  - Billing API:   https://api.$DOMAIN"
echo "  - Grafana:       https://grafana.$DOMAIN"
echo ""
echo "Next steps:"
echo ""
echo "1. Start the tunnel:"
echo "   $SCRIPT_DIR/run-tunnel.sh"
echo ""
echo "2. (Optional) Install as service:"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   cp $SCRIPT_DIR/config/com.cloudflare.temporal-tunnel.plist ~/Library/LaunchAgents/"
    echo "   launchctl load ~/Library/LaunchAgents/com.cloudflare.temporal-tunnel.plist"
else
    echo "   sudo cp $SCRIPT_DIR/config/cloudflared-temporal.service /etc/systemd/system/"
    echo "   sudo systemctl enable cloudflared-temporal"
    echo "   sudo systemctl start cloudflared-temporal"
fi
echo ""
echo "3. Configure OAuth/SSO (see OAUTH-SETUP.md)"
echo ""
