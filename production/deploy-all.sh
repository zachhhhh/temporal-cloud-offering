#!/bin/bash
set -e

# ============================================
# Temporal Cloud - Unified Production Deploy
# All services hosted together
# ============================================

echo "🚀 Temporal Cloud - Unified Production Deployment"
echo "=================================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ============================================
# Step 1: Check Prerequisites
# ============================================
echo -e "${BLUE}📋 Step 1: Checking prerequisites...${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Docker installed${NC}"

# Check Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found. Please install Docker Compose.${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Docker Compose installed${NC}"

# Check cloudflared
if ! command -v cloudflared &> /dev/null; then
    echo -e "${YELLOW}⚠️  cloudflared not found. Installing...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install cloudflared
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared.deb
        rm cloudflared.deb
    fi
fi
echo -e "${GREEN}  ✓ cloudflared installed${NC}"

echo ""

# ============================================
# Step 2: Environment Setup
# ============================================
echo -e "${BLUE}📝 Step 2: Setting up environment...${NC}"

# Create .env if not exists
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    cat > "$SCRIPT_DIR/.env" << 'EOF'
# Database
POSTGRES_PASSWORD=temporal_prod_$(openssl rand -hex 8)

# Stripe (replace with your keys)
STRIPE_SECRET_KEY=
STRIPE_PUBLISHABLE_KEY=
STRIPE_WEBHOOK_SECRET=

# Auth
NEXTAUTH_SECRET=$(openssl rand -base64 32)
NEXTAUTH_URL=http://localhost:3000

# Grafana
GRAFANA_PASSWORD=admin
EOF
    echo -e "${YELLOW}  Created .env file. Please add your Stripe keys.${NC}"
fi

source "$SCRIPT_DIR/.env" 2>/dev/null || true

echo -e "${GREEN}  ✓ Environment configured${NC}"
echo ""

# ============================================
# Step 3: Build All Services
# ============================================
echo -e "${BLUE}🔨 Step 3: Building all services...${NC}"

cd "$PROJECT_ROOT"

# Build admin portal
echo "  Building admin-portal..."
if [ -f "admin-portal/Dockerfile" ]; then
    docker build -t temporal-admin:latest ./admin-portal -q
else
    # Create Dockerfile if missing
    cat > admin-portal/Dockerfile << 'EOF'
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
EOF
    docker build -t temporal-admin:latest ./admin-portal -q
fi
echo -e "${GREEN}  ✓ admin-portal built${NC}"

# Build marketing site
echo "  Building marketing-site..."
if [ -f "marketing-site/Dockerfile" ]; then
    docker build -t temporal-marketing:latest ./marketing-site -q
else
    cat > marketing-site/Dockerfile << 'EOF'
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine AS runner
WORKDIR /app
COPY --from=builder /app/build ./build
COPY --from=builder /app/package*.json ./
RUN npm ci --production
EXPOSE 5173
CMD ["npm", "run", "preview", "--", "--host", "0.0.0.0"]
EOF
    docker build -t temporal-marketing:latest ./marketing-site -q
fi
echo -e "${GREEN}  ✓ marketing-site built${NC}"

# Build billing service
echo "  Building billing-service..."
if [ -f "billing-service/Dockerfile" ]; then
    docker build -t temporal-billing:latest ./billing-service -q
else
    cat > billing-service/Dockerfile << 'EOF'
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o billing-service .

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/billing-service .
EXPOSE 8082
CMD ["./billing-service"]
EOF
    docker build -t temporal-billing:latest ./billing-service -q
fi
echo -e "${GREEN}  ✓ billing-service built${NC}"

echo ""

# ============================================
# Step 4: Start All Services
# ============================================
echo -e "${BLUE}🐳 Step 4: Starting all services...${NC}"

cd "$SCRIPT_DIR"

# Create unified docker-compose
cat > docker-compose.unified.yaml << 'EOF'
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: temporal-postgres
    environment:
      POSTGRES_USER: temporal
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-temporal123}
      POSTGRES_DB: temporal
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U temporal"]
      interval: 5s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  # Temporal Server
  temporal:
    image: temporalio/auto-setup:latest
    container_name: temporal-server
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - DB=postgresql
      - DB_PORT=5432
      - POSTGRES_HOST=postgres
      - POSTGRES_USER=temporal
      - POSTGRES_PWD=${POSTGRES_PASSWORD:-temporal123}
      - POSTGRES_SEEDS=postgres
    ports:
      - "7233:7233"
    restart: unless-stopped

  # Temporal UI
  temporal-ui:
    image: temporalio/ui:latest
    container_name: temporal-ui
    depends_on:
      - temporal
    environment:
      - TEMPORAL_ADDRESS=temporal:7233
      - TEMPORAL_CORS_ORIGINS=*
    ports:
      - "8080:8080"
    restart: unless-stopped

  # Billing Service
  billing:
    image: temporal-billing:latest
    container_name: temporal-billing
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgres://temporal:${POSTGRES_PASSWORD:-temporal123}@postgres:5432/temporal?sslmode=disable
      - TEMPORAL_ADDRESS=temporal:7233
      - STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY:-}
      - PORT=8082
    ports:
      - "8082:8082"
    restart: unless-stopped

  # Admin Portal
  admin:
    image: temporal-admin:latest
    container_name: temporal-admin
    depends_on:
      - billing
      - temporal-ui
    environment:
      - NEXT_PUBLIC_BILLING_API=http://localhost:8082
      - NEXT_PUBLIC_TEMPORAL_UI=http://localhost:8080
      - NEXTAUTH_URL=${NEXTAUTH_URL:-http://localhost:3000}
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET:-change-me}
      - STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY:-}
      - STRIPE_PUBLISHABLE_KEY=${STRIPE_PUBLISHABLE_KEY:-}
    ports:
      - "3000:3000"
    restart: unless-stopped

  # Marketing Site
  marketing:
    image: temporal-marketing:latest
    container_name: temporal-marketing
    ports:
      - "5173:5173"
    restart: unless-stopped

volumes:
  postgres_data:
EOF

# Start services
docker-compose -f docker-compose.unified.yaml up -d

echo -e "${GREEN}  ✓ All services started${NC}"
echo ""

# Wait for services to be ready
echo -e "${BLUE}⏳ Waiting for services to be ready...${NC}"
sleep 10

# ============================================
# Step 5: Start Cloudflare Tunnels
# ============================================
echo -e "${BLUE}🌐 Step 5: Creating public tunnels...${NC}"
echo ""

# Kill any existing tunnels
pkill -f "cloudflared tunnel" 2>/dev/null || true
sleep 2

# Create tunnel URLs file
TUNNEL_FILE="$SCRIPT_DIR/tunnel-urls.txt"
> "$TUNNEL_FILE"

# Start tunnels in background
echo "  Starting tunnel for Marketing Site (port 5173)..."
cloudflared tunnel --url http://localhost:5173 2>&1 | grep -o 'https://[^[:space:]]*\.trycloudflare\.com' | head -1 >> "$TUNNEL_FILE" &
MARKETING_PID=$!
sleep 5

echo "  Starting tunnel for Admin Portal (port 3000)..."
cloudflared tunnel --url http://localhost:3000 2>&1 | grep -o 'https://[^[:space:]]*\.trycloudflare\.com' | head -1 >> "$TUNNEL_FILE" &
ADMIN_PID=$!
sleep 5

echo "  Starting tunnel for Temporal UI (port 8080)..."
cloudflared tunnel --url http://localhost:8080 2>&1 | grep -o 'https://[^[:space:]]*\.trycloudflare\.com' | head -1 >> "$TUNNEL_FILE" &
TEMPORAL_PID=$!
sleep 5

echo "  Starting tunnel for Billing API (port 8082)..."
cloudflared tunnel --url http://localhost:8082 2>&1 | grep -o 'https://[^[:space:]]*\.trycloudflare\.com' | head -1 >> "$TUNNEL_FILE" &
BILLING_PID=$!
sleep 5

# Get URLs from running tunnels
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}🎉 DEPLOYMENT COMPLETE!${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${YELLOW}📍 Local URLs:${NC}"
echo "   Marketing Site:  http://localhost:5173"
echo "   Admin Portal:    http://localhost:3000"
echo "   Temporal UI:     http://localhost:8080"
echo "   Billing API:     http://localhost:8082"
echo ""
echo -e "${YELLOW}🌐 Public URLs (via Cloudflare Tunnel):${NC}"
echo "   Check tunnel-urls.txt for public URLs"
echo "   Or run: cloudflared tunnel --url http://localhost:PORT"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "   1. Add your Stripe keys to .env"
echo "   2. Configure OAuth providers (Google, Microsoft)"
echo "   3. For permanent domain, set up Cloudflare Tunnel with your domain"
echo ""
echo -e "${YELLOW}🔧 Useful Commands:${NC}"
echo "   View logs:     docker-compose -f docker-compose.unified.yaml logs -f"
echo "   Stop all:      docker-compose -f docker-compose.unified.yaml down"
echo "   Restart:       docker-compose -f docker-compose.unified.yaml restart"
echo ""

# Save PIDs
echo "MARKETING_PID=$MARKETING_PID" > "$SCRIPT_DIR/.tunnel-pids"
echo "ADMIN_PID=$ADMIN_PID" >> "$SCRIPT_DIR/.tunnel-pids"
echo "TEMPORAL_PID=$TEMPORAL_PID" >> "$SCRIPT_DIR/.tunnel-pids"
echo "BILLING_PID=$BILLING_PID" >> "$SCRIPT_DIR/.tunnel-pids"
