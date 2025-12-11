#!/bin/bash
set -e

# ============================================
# Temporal Cloud Offering - Production Go-Live
# ============================================

echo "🚀 Temporal Cloud Offering - Production Deployment"
echo "=================================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo -e "${YELLOW}⚠️  No .env.production found. Creating from template...${NC}"
    cp .env.production.template .env.production
    echo -e "${RED}❌ Please edit .env.production with your production values before continuing.${NC}"
    echo ""
    echo "Required values:"
    echo "  - DOMAIN: Your domain name"
    echo "  - STRIPE_SECRET_KEY: Your Stripe secret key"
    echo "  - STRIPE_PUBLISHABLE_KEY: Your Stripe publishable key"
    echo "  - NEXTAUTH_SECRET: A random secret (generate with: openssl rand -base64 32)"
    echo ""
    exit 1
fi

# Load environment
source .env.production

# Validate required variables
REQUIRED_VARS=("DOMAIN" "STRIPE_SECRET_KEY" "STRIPE_PUBLISHABLE_KEY" "NEXTAUTH_SECRET")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ] || [[ "${!var}" == *"xxxxx"* ]] || [[ "${!var}" == *"your-"* ]]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing or invalid required variables:${NC}"
    for var in "${MISSING_VARS[@]}"; do
        echo "   - $var"
    done
    echo ""
    echo "Please update .env.production with valid values."
    exit 1
fi

echo -e "${GREEN}✅ Environment validated${NC}"
echo ""

# ============================================
# Step 1: Build Docker Images
# ============================================
echo -e "${BLUE}📦 Step 1: Building Docker images...${NC}"

cd ..

# Build admin portal
echo "Building admin-portal..."
docker build -t temporal-cloud-admin:latest ./admin-portal

# Build marketing site
echo "Building marketing-site..."
docker build -t temporal-cloud-marketing:latest ./marketing-site

# Build billing service
echo "Building billing-service..."
docker build -t temporal-cloud-billing:latest ./billing-service

echo -e "${GREEN}✅ Docker images built${NC}"
echo ""

# ============================================
# Step 2: Choose Deployment Method
# ============================================
echo -e "${BLUE}🌐 Step 2: Choose deployment method${NC}"
echo ""
echo "1) Cloudflare Tunnel (Recommended - Free, works from any network)"
echo "2) Docker Compose (Local server with public IP)"
echo "3) Kubernetes (For scaling)"
echo "4) Deploy to Netlify/Vercel (Static + Serverless)"
echo ""
read -p "Select option (1-4): " DEPLOY_OPTION

case $DEPLOY_OPTION in
    1)
        echo -e "${BLUE}🔧 Setting up Cloudflare Tunnel...${NC}"
        cd production/cloudflare-tunnel
        
        # Check if cloudflared is installed
        if ! command -v cloudflared &> /dev/null; then
            echo "Installing cloudflared..."
            if [[ "$OSTYPE" == "darwin"* ]]; then
                brew install cloudflared
            else
                curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
                sudo dpkg -i cloudflared.deb
                rm cloudflared.deb
            fi
        fi
        
        echo ""
        echo "To set up a permanent tunnel, you need to:"
        echo "1. Login to Cloudflare: cloudflared tunnel login"
        echo "2. Create a tunnel: cloudflared tunnel create temporal-cloud"
        echo "3. Configure DNS in Cloudflare dashboard"
        echo ""
        echo "For now, starting quick tunnels for testing..."
        
        # Start services with docker-compose
        cd ..
        docker-compose -f docker-compose.prod.yaml up -d
        
        # Start quick tunnels
        cd cloudflare-tunnel
        ./start-quick-tunnels.sh
        ;;
        
    2)
        echo -e "${BLUE}🐳 Starting Docker Compose...${NC}"
        cd production
        docker-compose -f docker-compose.prod.yaml up -d
        
        echo ""
        echo -e "${GREEN}✅ Services started!${NC}"
        echo ""
        echo "Services running at:"
        echo "  - Admin Portal: http://localhost:3002"
        echo "  - Marketing Site: http://localhost:5173"
        echo "  - Billing API: http://localhost:8082"
        echo ""
        echo "To expose publicly, configure your firewall and DNS."
        ;;
        
    3)
        echo -e "${BLUE}☸️  Deploying to Kubernetes...${NC}"
        cd production
        
        # Check if kubectl is available
        if ! command -v kubectl &> /dev/null; then
            echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
            exit 1
        fi
        
        # Apply manifests
        kubectl apply -f k8s-production/
        
        echo -e "${GREEN}✅ Deployed to Kubernetes${NC}"
        ;;
        
    4)
        echo -e "${BLUE}☁️  Deploying to Netlify...${NC}"
        
        # Deploy marketing site to Netlify
        cd marketing-site
        
        if ! command -v netlify &> /dev/null; then
            echo "Installing Netlify CLI..."
            npm install -g netlify-cli
        fi
        
        echo "Building marketing site..."
        npm run build
        
        echo "Deploying to Netlify..."
        netlify deploy --prod --dir=build
        
        # Deploy admin portal
        cd ../admin-portal
        echo "Building admin portal..."
        npm run build
        
        echo "Deploying admin portal to Netlify..."
        netlify deploy --prod --dir=.next
        
        echo -e "${GREEN}✅ Deployed to Netlify${NC}"
        ;;
        
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo "============================================"
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Configure your domain DNS to point to the deployment"
echo "2. Set up SSL certificates (automatic with Cloudflare)"
echo "3. Configure Stripe webhook endpoint"
echo "4. Test the payment flow"
echo ""
echo "Stripe Webhook URL: https://app.${DOMAIN}/api/stripe/webhook"
echo ""
