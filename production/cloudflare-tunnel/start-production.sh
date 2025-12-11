#!/bin/bash
# Production Start Script - Cloudflare Quick Tunnels
# Creates public URLs for all services (no domain required)

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Temporal Cloud - Production Tunnels                    ║${NC}"
echo -e "${BLUE}║     Free SSL + Public URLs (trycloudflare.com)             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check services
echo "Checking local services..."
services_ok=true

check_service() {
    if curl -s "http://localhost:$1" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $2 (port $1)"
    else
        echo -e "  ${RED}✗${NC} $2 (port $1) - NOT RUNNING"
        services_ok=false
    fi
}

check_service 3002 "Marketing Site"
check_service 8080 "Temporal UI"
check_service 3000 "Admin Portal"
check_service 3001 "Grafana"
check_service 8082 "Billing API"

if [ "$services_ok" = false ]; then
    echo ""
    echo -e "${RED}Some services are not running!${NC}"
    echo "Start them with: cd deploy && docker-compose up -d"
    exit 1
fi

echo ""
echo -e "${GREEN}All services running!${NC}"
echo ""

# Kill any existing tunnels
pkill -f "cloudflared tunnel" 2>/dev/null || true
sleep 1

echo "Starting tunnels (this takes ~10 seconds)..."
echo ""

# Start tunnels and capture URLs
start_tunnel() {
    local port=$1
    local name=$2
    local log_file="$LOG_DIR/${name}.log"
    
    cloudflared tunnel --url "http://localhost:$port" --protocol http2 > "$log_file" 2>&1 &
    echo $!
}

# Start all tunnels
MARKETING_PID=$(start_tunnel 3002 "marketing")
TEMPORAL_PID=$(start_tunnel 8080 "temporal-ui")
ADMIN_PID=$(start_tunnel 3000 "admin-portal")
GRAFANA_PID=$(start_tunnel 3001 "grafana")
API_PID=$(start_tunnel 8082 "billing-api")

# Wait for URLs to be generated
echo "Waiting for tunnel URLs..."
sleep 12

# Extract URLs from logs
get_url() {
    grep -o 'https://[^[:space:]]*\.trycloudflare\.com' "$LOG_DIR/$1.log" 2>/dev/null | head -1
}

MARKETING_URL=$(get_url "marketing")
TEMPORAL_URL=$(get_url "temporal-ui")
ADMIN_URL=$(get_url "admin-portal")
GRAFANA_URL=$(get_url "grafana")
API_URL=$(get_url "billing-api")

# Save URLs
cat > "$SCRIPT_DIR/.env.urls" << EOF
# Generated: $(date)
# These URLs change on restart

MARKETING_URL=$MARKETING_URL
TEMPORAL_UI_URL=$TEMPORAL_URL
ADMIN_PORTAL_URL=$ADMIN_URL
GRAFANA_URL=$GRAFANA_URL
BILLING_API_URL=$API_URL

# PIDs (for stopping)
MARKETING_PID=$MARKETING_PID
TEMPORAL_PID=$TEMPORAL_PID
ADMIN_PID=$ADMIN_PID
GRAFANA_PID=$GRAFANA_PID
API_PID=$API_PID
EOF

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Tunnels Active!                                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Your services are now publicly accessible:"
echo ""
echo -e "  ${BLUE}Marketing Site:${NC} $MARKETING_URL  (like temporal.io)"
echo -e "  ${BLUE}Temporal UI:${NC}    $TEMPORAL_URL"
echo -e "  ${BLUE}Admin Portal:${NC}   $ADMIN_URL  (dashboard after login)"
echo -e "  ${BLUE}Grafana:${NC}        $GRAFANA_URL"
echo -e "  ${BLUE}Billing API:${NC}    $API_URL"
echo ""
echo -e "${YELLOW}Note: URLs change each restart. For permanent URLs, get a domain.${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Commands:"
echo "  Stop tunnels:  $SCRIPT_DIR/stop-tunnels.sh"
echo "  View logs:     tail -f $LOG_DIR/*.log"
echo ""
echo "Tunnels running in background. Press Ctrl+C or run stop script."
echo ""

# Create stop script
cat > "$SCRIPT_DIR/stop-tunnels.sh" << 'STOPEOF'
#!/bin/bash
echo "Stopping all tunnels..."
pkill -f "cloudflared tunnel" 2>/dev/null
echo "Done."
STOPEOF
chmod +x "$SCRIPT_DIR/stop-tunnels.sh"

# Keep script running to show it's active
echo "Monitoring tunnels (Ctrl+C to exit, tunnels keep running)..."
while true; do
    sleep 60
    # Check if tunnels still running
    if ! ps -p $TEMPORAL_PID > /dev/null 2>&1; then
        echo -e "${RED}Temporal UI tunnel died, restarting...${NC}"
        TEMPORAL_PID=$(start_tunnel 8080 "temporal-ui")
    fi
done
