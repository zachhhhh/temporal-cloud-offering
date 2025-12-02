#!/bin/bash
# Free Domain Setup Script
# Options: DuckDNS, FreeDNS, No-IP, or nip.io

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Free Domain Setup for Temporal Cloud${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get server IP
SERVER_IP="${1:-$(curl -s ifconfig.me)}"
log_info "Server IP: $SERVER_IP"
echo ""

echo "Choose a free domain option:"
echo ""
echo "1. DuckDNS (Recommended)"
echo "   - Free subdomains: yourname.duckdns.org"
echo "   - Supports wildcard SSL"
echo "   - Easy API for updates"
echo ""
echo "2. nip.io (Instant, no signup)"
echo "   - Format: app.${SERVER_IP}.nip.io"
echo "   - No registration needed"
echo "   - Works immediately"
echo ""
echo "3. sslip.io (Similar to nip.io)"
echo "   - Format: app.${SERVER_IP}.sslip.io"
echo "   - No registration needed"
echo ""
echo "4. FreeDNS (afraid.org)"
echo "   - Many free subdomains available"
echo "   - More domain options"
echo ""

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo ""
        log_info "DuckDNS Setup"
        echo ""
        echo "1. Go to https://www.duckdns.org"
        echo "2. Sign in with Google/GitHub/Twitter"
        echo "3. Create a subdomain (e.g., 'mytemporal')"
        echo "4. Copy your token"
        echo ""
        read -p "Enter your DuckDNS subdomain (without .duckdns.org): " DUCKDNS_SUBDOMAIN
        read -p "Enter your DuckDNS token: " DUCKDNS_TOKEN
        
        # Update DuckDNS
        RESULT=$(curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip=${SERVER_IP}")
        
        if [ "$RESULT" = "OK" ]; then
            log_info "DuckDNS updated successfully!"
            DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
        else
            log_warn "DuckDNS update failed: $RESULT"
            exit 1
        fi
        
        # Create update script
        cat > /tmp/duckdns-update.sh << EOF
#!/bin/bash
curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}&ip="
EOF
        chmod +x /tmp/duckdns-update.sh
        log_info "Update script created at /tmp/duckdns-update.sh"
        ;;
        
    2)
        DOMAIN="${SERVER_IP}.nip.io"
        log_info "Using nip.io - no setup needed!"
        ;;
        
    3)
        DOMAIN="${SERVER_IP}.sslip.io"
        log_info "Using sslip.io - no setup needed!"
        ;;
        
    4)
        echo ""
        log_info "FreeDNS Setup"
        echo ""
        echo "1. Go to https://freedns.afraid.org"
        echo "2. Create an account"
        echo "3. Go to 'Subdomains' and add a new one"
        echo "4. Choose from available domains"
        echo ""
        read -p "Enter your full FreeDNS domain: " DOMAIN
        ;;
        
    *)
        log_warn "Invalid choice"
        exit 1
        ;;
esac

echo ""
log_info "Domain configured: $DOMAIN"
echo ""

# Generate domain configuration
cat << EOF

========================================
  Your Domain Configuration
========================================

Base Domain: $DOMAIN

Subdomains to configure:
  - app.$DOMAIN      -> Admin Portal
  - api.$DOMAIN      -> Billing API  
  - temporal.$DOMAIN -> Temporal UI
  - grpc.$DOMAIN     -> Temporal gRPC

For nip.io/sslip.io, use:
  - app-${SERVER_IP//./-}.nip.io
  - api-${SERVER_IP//./-}.nip.io
  - temporal-${SERVER_IP//./-}.nip.io

========================================

EOF

# Update nginx.conf
log_info "Updating nginx.conf with domain..."

NGINX_CONF="production/nginx.conf"
if [ -f "$NGINX_CONF" ]; then
    sed -i.bak "s/yourdomain.com/$DOMAIN/g" "$NGINX_CONF"
    log_info "Updated $NGINX_CONF"
fi

# Update ingress
for file in production/k8s-manifests/*.yaml; do
    if grep -q "yourdomain.com" "$file" 2>/dev/null; then
        sed -i.bak "s/yourdomain.com/$DOMAIN/g" "$file"
        log_info "Updated $file"
    fi
done

echo ""
log_info "Domain setup complete!"
echo ""
echo "Next steps:"
echo "1. Deploy your application"
echo "2. Set up SSL with Let's Encrypt"
echo "3. Test your endpoints"
EOF
