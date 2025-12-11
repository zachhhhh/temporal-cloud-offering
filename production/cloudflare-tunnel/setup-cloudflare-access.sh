#!/bin/bash
# Setup Cloudflare Access for SSO
# This script configures Cloudflare Access applications for your Temporal Cloud deployment
# Usage: ./setup-cloudflare-access.sh <email> <api_key> <domain> <account_id>

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 4 ]; then
    echo "Usage: $0 <cloudflare_email> <api_key> <domain> <account_id>"
    echo ""
    echo "Example: $0 user@example.com abc123xyz example.com 1234567890abcdef"
    echo ""
    echo "Get your Account ID from: https://dash.cloudflare.com/"
    exit 1
fi

CF_EMAIL="$1"
CF_API_KEY="$2"
DOMAIN="$3"
ACCOUNT_ID="$4"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Cloudflare Access Setup              ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to create Access Application
create_access_app() {
    local name="$1"
    local subdomain="$2"
    local session_duration="${3:-24h}"
    
    echo "Creating Access Application: $name..."
    
    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/apps" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json" \
        --data "{
            \"name\": \"$name\",
            \"domain\": \"$subdomain.$DOMAIN\",
            \"type\": \"self_hosted\",
            \"session_duration\": \"$session_duration\",
            \"auto_redirect_to_identity\": true,
            \"allowed_idps\": [],
            \"cors_headers\": {
                \"allowed_methods\": [\"GET\", \"POST\", \"PUT\", \"DELETE\", \"OPTIONS\"],
                \"allowed_origins\": [\"https://$subdomain.$DOMAIN\"],
                \"allow_credentials\": true
            }
        }")
    
    APP_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['result']['id'] if r.get('success') else '')" 2>/dev/null)
    AUD=$(echo "$RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['result']['aud'] if r.get('success') else '')" 2>/dev/null)
    
    if [ -n "$APP_ID" ]; then
        echo -e "  ${GREEN}✓${NC} Created: $name (ID: $APP_ID)"
        echo "$subdomain:$APP_ID:$AUD" >> "$SCRIPT_DIR/config/access-apps.txt"
    else
        # Check if already exists
        EXISTING=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/apps?name=$name" \
            -H "X-Auth-Email: $CF_EMAIL" \
            -H "X-Auth-Key: $CF_API_KEY" \
            -H "Content-Type: application/json")
        
        APP_ID=$(echo "$EXISTING" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['result'][0]['id'] if r.get('success') and r.get('result') else '')" 2>/dev/null)
        
        if [ -n "$APP_ID" ]; then
            echo -e "  ${YELLOW}⚠${NC} Already exists: $name (ID: $APP_ID)"
        else
            echo -e "  ${RED}✗${NC} Failed to create: $name"
            echo "Response: $RESPONSE"
        fi
    fi
}

# Function to create Access Policy
create_access_policy() {
    local app_id="$1"
    local policy_name="$2"
    local include_type="$3"  # "emails" or "email_domain"
    local include_value="$4"
    
    echo "  Creating policy: $policy_name..."
    
    local include_rule
    if [ "$include_type" = "emails" ]; then
        include_rule="{\"email\": {\"email\": \"$include_value\"}}"
    else
        include_rule="{\"email_domain\": {\"domain\": \"$include_value\"}}"
    fi
    
    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/apps/$app_id/policies" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json" \
        --data "{
            \"name\": \"$policy_name\",
            \"decision\": \"allow\",
            \"include\": [$include_rule],
            \"precedence\": 1
        }")
    
    SUCCESS=$(echo "$RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print('true' if r.get('success') else 'false')" 2>/dev/null)
    
    if [ "$SUCCESS" = "true" ]; then
        echo -e "    ${GREEN}✓${NC} Policy created"
    else
        echo -e "    ${YELLOW}⚠${NC} Policy may already exist"
    fi
}

# Create config directory
mkdir -p "$SCRIPT_DIR/config"
> "$SCRIPT_DIR/config/access-apps.txt"

# Create Access Applications
echo ""
echo "Creating Access Applications..."
echo ""

create_access_app "Temporal Cloud - Admin Portal" "app"
create_access_app "Temporal Cloud - Temporal UI" "temporal"
create_access_app "Temporal Cloud - Grafana" "grafana"
create_access_app "Temporal Cloud - API" "api"

# Get the admin portal app ID for policy creation
ADMIN_APP_ID=$(grep "^app:" "$SCRIPT_DIR/config/access-apps.txt" | cut -d: -f2)

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "IMPORTANT: Configure Identity Providers"
echo ""
echo "1. Go to: https://one.dash.cloudflare.com/$ACCOUNT_ID/access/identity-providers"
echo ""
echo "2. Add identity providers (recommended):"
echo "   - Google (one-click setup)"
echo "   - GitHub"
echo "   - One-time PIN (email-based)"
echo ""
echo "3. Create Access Policies:"
echo "   Go to each application and add policies to control access."
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Ask for email domain to allow
read -p "Enter email domain to allow (e.g., yourcompany.com) or press Enter to skip: " EMAIL_DOMAIN

if [ -n "$EMAIL_DOMAIN" ]; then
    echo ""
    echo "Creating access policies for @$EMAIL_DOMAIN..."
    
    for line in $(cat "$SCRIPT_DIR/config/access-apps.txt"); do
        subdomain=$(echo "$line" | cut -d: -f1)
        app_id=$(echo "$line" | cut -d: -f2)
        
        if [ -n "$app_id" ]; then
            create_access_policy "$app_id" "Allow $EMAIL_DOMAIN" "email_domain" "$EMAIL_DOMAIN"
        fi
    done
fi

# Save configuration for the admin portal
echo ""
echo "Saving configuration..."

# Get the AUD tag for the admin portal
ADMIN_AUD=$(grep "^app:" "$SCRIPT_DIR/config/access-apps.txt" | cut -d: -f3)

cat >> "$SCRIPT_DIR/.env" << EOF

# Cloudflare Access Configuration
CF_ACCESS_TEAM_DOMAIN=${ACCOUNT_ID}.cloudflareaccess.com
CF_ACCESS_AUD=$ADMIN_AUD
AUTH_MODE=cloudflare-access
EOF

# Create admin portal .env.production
cat > "$SCRIPT_DIR/../../admin-portal/.env.production" << EOF
# Production Environment - Cloudflare Access
NEXT_PUBLIC_AUTH_MODE=cloudflare-access
NEXT_PUBLIC_CF_ACCESS_TEAM_DOMAIN=${ACCOUNT_ID}.cloudflareaccess.com
CF_ACCESS_TEAM_DOMAIN=${ACCOUNT_ID}.cloudflareaccess.com
CF_ACCESS_AUD=$ADMIN_AUD

# Service URLs
NEXT_PUBLIC_BILLING_API_URL=https://api.$DOMAIN
NEXT_PUBLIC_TEMPORAL_UI_URL=https://temporal.$DOMAIN

# NextAuth (disabled in production with Cloudflare Access)
# NEXTAUTH_URL=https://app.$DOMAIN
# NEXTAUTH_SECRET=not-needed-with-cloudflare-access
EOF

echo -e "${GREEN}✓${NC} Configuration saved"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cloudflare Access Setup Complete!    ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your services are now protected by Cloudflare Access:"
echo ""
echo "  Admin Portal:  https://app.$DOMAIN"
echo "  Temporal UI:   https://temporal.$DOMAIN"
echo "  Grafana:       https://grafana.$DOMAIN"
echo "  API:           https://api.$DOMAIN"
echo ""
echo "Next steps:"
echo "1. Configure identity providers in Cloudflare Zero Trust dashboard"
echo "2. Add access policies to control who can access each application"
echo "3. Start your services with: docker-compose -f docker-compose.tunnel.yaml up -d"
echo "4. Start the tunnel with: ./run.sh"
echo ""
