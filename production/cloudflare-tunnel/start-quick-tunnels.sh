#!/bin/bash
# Start quick tunnels for all services
# These are temporary URLs that change on restart

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

echo "Starting Cloudflare Quick Tunnels..."
echo ""

# Kill any existing tunnels
pkill -f "cloudflared tunnel" 2>/dev/null || true
sleep 2

# Start tunnel for Admin Portal (port 3002)
echo "Starting Admin Portal tunnel (port 3002)..."
cloudflared tunnel --url http://localhost:3002 --protocol http2 > "$LOG_DIR/admin.log" 2>&1 &
ADMIN_PID=$!
sleep 4

# Extract URL
ADMIN_URL=$(grep -o 'https://[^|]*trycloudflare.com' "$LOG_DIR/admin.log" | tail -1 | tr -d ' ')
echo "  Admin Portal: $ADMIN_URL"

# Start tunnel for Marketing Site (port 5173)
echo "Starting Marketing Site tunnel (port 5173)..."
cloudflared tunnel --url http://localhost:5173 --protocol http2 > "$LOG_DIR/marketing.log" 2>&1 &
MARKETING_PID=$!
sleep 4

MARKETING_URL=$(grep -o 'https://[^|]*trycloudflare.com' "$LOG_DIR/marketing.log" | tail -1 | tr -d ' ')
echo "  Marketing Site: $MARKETING_URL"

# Save URLs
cat > "$SCRIPT_DIR/.env.urls" << EOF
# Generated: $(date)
# Quick Tunnel URLs (change on restart)

ADMIN_PORTAL_URL=$ADMIN_URL
MARKETING_SITE_URL=$MARKETING_URL

# PIDs
ADMIN_PID=$ADMIN_PID
MARKETING_PID=$MARKETING_PID
EOF

echo ""
echo "=========================================="
echo "  Quick Tunnels Started!"
echo "=========================================="
echo ""
echo "Public URLs:"
echo ""
echo "  Admin Portal:   $ADMIN_URL"
echo "  Marketing Site: $MARKETING_URL"
echo ""
echo "URLs saved to: $SCRIPT_DIR/.env.urls"
echo ""
echo "To stop tunnels: pkill -f 'cloudflared tunnel'"
echo ""
