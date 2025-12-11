#!/bin/bash
# Production Deployment Script for Temporal Cloud Offering
# This script sets up everything needed for production with Cloudflare
# Usage: ./deploy-production.sh

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Temporal Cloud Offering - Production Deployment          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for required tools
check_requirements() {
    echo "Checking requirements..."
    
    for cmd in docker docker-compose cloudflared curl python3; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}Error: $cmd is not installed${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}✓${NC} All requirements met"
    echo ""
}

# Load or prompt for configuration
load_config() {
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
        echo "Loaded existing configuration for: $DOMAIN"
        echo ""
    fi
    
    if [ -z "$DOMAIN" ]; then
        read -p "Enter your domain (e.g., temporal.example.com): " DOMAIN
    fi
    
    if [ -z "$CF_EMAIL" ]; then
        read -p "Enter your Cloudflare email: " CF_EMAIL
    fi
    
    if [ -z "$CF_API_KEY" ]; then
        read -sp "Enter your Cloudflare API key: " CF_API_KEY
        echo ""
    fi
    
    # Optional: Stripe for billing
    if [ -z "$STRIPE_SECRET_KEY" ]; then
        read -p "Enter Stripe Secret Key (or press Enter to skip): " STRIPE_SECRET_KEY
    fi
    
    # Generate secrets if not set
    if [ -z "$POSTGRES_PASSWORD" ]; then
        POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
    fi
    
    if [ -z "$NEXTAUTH_SECRET" ]; then
        NEXTAUTH_SECRET=$(openssl rand -base64 32)
    fi
    
    if [ -z "$GRAFANA_PASSWORD" ]; then
        GRAFANA_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
    fi
}

# Setup Cloudflare Tunnel
setup_tunnel() {
    echo ""
    echo -e "${BLUE}Setting up Cloudflare Tunnel...${NC}"
    
    if [ -z "$TUNNEL_ID" ]; then
        "$SCRIPT_DIR/setup-with-api.sh" "$CF_EMAIL" "$CF_API_KEY" "$DOMAIN"
        source "$SCRIPT_DIR/.env"
    else
        echo "Tunnel already configured: $TUNNEL_ID"
    fi
}

# Setup Cloudflare Access
setup_access() {
    echo ""
    echo -e "${BLUE}Setting up Cloudflare Access (SSO)...${NC}"
    
    read -p "Setup Cloudflare Access for SSO? (y/n): " SETUP_ACCESS
    
    if [ "$SETUP_ACCESS" = "y" ]; then
        "$SCRIPT_DIR/setup-cloudflare-access.sh" "$CF_EMAIL" "$CF_API_KEY" "$DOMAIN" "$ACCOUNT_ID"
    fi
}

# Build Docker images
build_images() {
    echo ""
    echo -e "${BLUE}Building Docker images...${NC}"
    
    # Build billing service
    echo "Building billing-service..."
    docker build -t temporal-billing:latest "$PROJECT_ROOT/billing-service"
    
    # Build admin portal
    echo "Building admin-portal..."
    docker build -t temporal-admin-portal:latest "$PROJECT_ROOT/admin-portal"
    
    # Build usage collector (if exists)
    if [ -d "$PROJECT_ROOT/usage-collector" ]; then
        echo "Building usage-collector..."
        docker build -t temporal-usage-collector:latest "$PROJECT_ROOT/usage-collector"
    fi
    
    echo -e "${GREEN}✓${NC} All images built"
}

# Create production environment file
create_env_file() {
    echo ""
    echo -e "${BLUE}Creating production environment file...${NC}"
    
    cat > "$SCRIPT_DIR/.env.production" << EOF
# Production Environment Configuration
# Generated: $(date)

# Domain
DOMAIN=$DOMAIN

# Cloudflare
CF_EMAIL=$CF_EMAIL
ZONE_ID=$ZONE_ID
ACCOUNT_ID=$ACCOUNT_ID
TUNNEL_ID=$TUNNEL_ID
TUNNEL_TOKEN=$TUNNEL_TOKEN

# Database
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Auth
AUTH_MODE=${AUTH_MODE:-cloudflare-access}
NEXTAUTH_SECRET=$NEXTAUTH_SECRET
CF_ACCESS_TEAM_DOMAIN=${ACCOUNT_ID}.cloudflareaccess.com

# Stripe (Billing)
STRIPE_SECRET_KEY=$STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET=$STRIPE_WEBHOOK_SECRET

# Grafana
GRAFANA_PASSWORD=$GRAFANA_PASSWORD

# Service URLs
APP_URL=https://app.$DOMAIN
TEMPORAL_URL=https://temporal.$DOMAIN
API_URL=https://api.$DOMAIN
GRAFANA_URL=https://grafana.$DOMAIN
EOF

    chmod 600 "$SCRIPT_DIR/.env.production"
    echo -e "${GREEN}✓${NC} Environment file created"
}

# Start services
start_services() {
    echo ""
    echo -e "${BLUE}Starting services...${NC}"
    
    # Copy env file
    cp "$SCRIPT_DIR/.env.production" "$SCRIPT_DIR/.env"
    
    # Start with docker-compose
    cd "$SCRIPT_DIR"
    docker-compose -f docker-compose.tunnel.yaml up -d
    
    echo ""
    echo "Waiting for services to start..."
    sleep 10
    
    # Check service health
    echo ""
    echo "Checking service health..."
    
    for service in temporal-postgres temporal-server temporal-ui temporal-billing temporal-admin-portal; do
        if docker ps | grep -q $service; then
            echo -e "  ${GREEN}✓${NC} $service is running"
        else
            echo -e "  ${RED}✗${NC} $service is not running"
        fi
    done
}

# Start tunnel
start_tunnel() {
    echo ""
    echo -e "${BLUE}Starting Cloudflare Tunnel...${NC}"
    
    # Start tunnel in background
    nohup cloudflared tunnel --config "$SCRIPT_DIR/config/config.yml" run > "$SCRIPT_DIR/logs/tunnel.log" 2>&1 &
    TUNNEL_PID=$!
    echo $TUNNEL_PID > "$SCRIPT_DIR/logs/tunnel.pid"
    
    echo "Tunnel started with PID: $TUNNEL_PID"
    echo "Logs: $SCRIPT_DIR/logs/tunnel.log"
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Deployment Complete!                            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Your Temporal Cloud is now running at:"
    echo ""
    echo -e "  ${BLUE}Admin Portal:${NC}  https://app.$DOMAIN"
    echo -e "  ${BLUE}Temporal UI:${NC}   https://temporal.$DOMAIN"
    echo -e "  ${BLUE}Billing API:${NC}   https://api.$DOMAIN"
    echo -e "  ${BLUE}Grafana:${NC}       https://grafana.$DOMAIN"
    echo ""
    echo "Credentials:"
    echo ""
    echo -e "  ${YELLOW}Grafana:${NC} admin / $GRAFANA_PASSWORD"
    echo ""
    echo "Authentication:"
    if [ "$AUTH_MODE" = "cloudflare-access" ]; then
        echo "  Using Cloudflare Access (SSO)"
        echo "  Configure identity providers at: https://one.dash.cloudflare.com/"
    else
        echo "  Using NextAuth (OAuth)"
        echo "  Configure OAuth providers in .env"
    fi
    echo ""
    echo "Useful commands:"
    echo ""
    echo "  View logs:     docker-compose -f docker-compose.tunnel.yaml logs -f"
    echo "  Stop services: docker-compose -f docker-compose.tunnel.yaml down"
    echo "  Stop tunnel:   kill \$(cat logs/tunnel.pid)"
    echo ""
}

# Main
main() {
    check_requirements
    load_config
    setup_tunnel
    setup_access
    build_images
    create_env_file
    start_services
    
    mkdir -p "$SCRIPT_DIR/logs"
    start_tunnel
    
    print_summary
}

main "$@"
