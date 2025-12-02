#!/bin/bash
# Quick Cloudflare Tunnel - No login required!
# Uses trycloudflare.com for instant free domain
# Perfect for demos and testing

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Quick Tunnel (No Login Required)     ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check services are running
echo "Checking services..."
if ! curl -s http://localhost:8080 > /dev/null 2>&1; then
    echo "Error: Temporal UI not running on localhost:8080"
    echo "Run: cd deploy && docker-compose up -d"
    exit 1
fi

if ! curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo "Error: Admin Portal not running on localhost:3000"
    exit 1
fi

echo -e "${GREEN}Services are running!${NC}"
echo ""
echo -e "${YELLOW}Starting tunnels - watch for URLs below...${NC}"
echo ""
echo "Each tunnel will print a URL like:"
echo "  https://xxxxx-xxxxx-xxxxx.trycloudflare.com"
echo ""
echo "Copy those URLs to access your services."
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Run single tunnel for Temporal UI (main service)
echo -e "${GREEN}[Temporal UI - port 8080]${NC}"
echo "Starting tunnel..."
cloudflared tunnel --url http://localhost:8080
