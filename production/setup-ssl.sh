#!/bin/bash
# SSL Certificate Setup with Let's Encrypt
# For nip.io domains, we'll use self-signed certs (Let's Encrypt doesn't support nip.io)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$SCRIPT_DIR/ssl"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Create SSL directory
mkdir -p "$SSL_DIR"

# Get domain from .env or use default
DOMAIN="${DOMAIN:-138.2.104.236.nip.io}"

echo "=========================================="
echo "  SSL Certificate Setup"
echo "=========================================="
echo ""

# Check if using nip.io (can't use Let's Encrypt)
if [[ "$DOMAIN" == *".nip.io"* ]] || [[ "$DOMAIN" == *".sslip.io"* ]]; then
    log_warn "nip.io/sslip.io domains don't support Let's Encrypt"
    log_info "Generating self-signed certificate..."
    
    # Generate self-signed certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/privkey.pem" \
        -out "$SSL_DIR/fullchain.pem" \
        -subj "/C=US/ST=State/L=City/O=Temporal Cloud/CN=*.$DOMAIN" \
        -addext "subjectAltName=DNS:*.$DOMAIN,DNS:$DOMAIN"
    
    log_info "Self-signed certificate generated!"
    log_info "Location: $SSL_DIR/"
    echo ""
    log_warn "Note: Browsers will show a security warning for self-signed certs"
    log_info "For production, use a real domain with Let's Encrypt"
    
else
    log_info "Setting up Let's Encrypt for $DOMAIN..."
    
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        log_info "Installing certbot..."
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y certbot
        elif command -v yum &> /dev/null; then
            sudo yum install -y certbot
        elif command -v brew &> /dev/null; then
            brew install certbot
        else
            log_warn "Please install certbot manually"
            exit 1
        fi
    fi
    
    # Get certificates
    sudo certbot certonly --standalone \
        -d "app.$DOMAIN" \
        -d "api.$DOMAIN" \
        -d "temporal.$DOMAIN" \
        -d "grpc.$DOMAIN" \
        --agree-tos \
        --non-interactive \
        --email "admin@$DOMAIN"
    
    # Copy certificates
    sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$SSL_DIR/"
    sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$SSL_DIR/"
    sudo chown $USER:$USER "$SSL_DIR/"*
    
    log_info "Let's Encrypt certificates installed!"
    
    # Setup auto-renewal
    echo "0 0 * * * certbot renew --quiet" | sudo crontab -
    log_info "Auto-renewal configured"
fi

echo ""
echo "=========================================="
echo "  SSL Setup Complete"
echo "=========================================="
echo ""
echo "Certificate files:"
echo "  - $SSL_DIR/fullchain.pem"
echo "  - $SSL_DIR/privkey.pem"
echo ""
