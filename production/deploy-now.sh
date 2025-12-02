#!/bin/bash
# One-Click Production Deployment
# Deploys to OCI K3s or local Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}========================================${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}========================================${NC}"; }

OCI_IP="138.2.104.236"
DOMAIN="${OCI_IP}.nip.io"

log_section "Temporal Cloud Production Deployment"

echo ""
echo "Deployment Options:"
echo "1. Deploy to OCI K3s (IP: $OCI_IP)"
echo "2. Deploy locally with Docker Compose"
echo "3. Build images only"
echo ""

read -p "Enter choice (1-3): " choice

case $choice in
    1)
        log_section "Deploying to OCI K3s"
        
        # Check if K3s is ready
        log_info "Checking K3s cluster status..."
        
        # Try to get kubeconfig from OCI
        KUBECONFIG_FILE="$HOME/.kube/config-oci"
        
        if [ ! -f "$KUBECONFIG_FILE" ]; then
            log_info "Fetching kubeconfig from K3s server..."
            
            # Find the SSH key
            SSH_KEY="$HOME/.oci/oci_api_key.pem"
            if [ ! -f "$SSH_KEY" ]; then
                SSH_KEY="$HOME/Downloads/gchen2036@gmail.com-2025-12-01T08_59_20.010Z.pem"
            fi
            
            if [ ! -f "$SSH_KEY" ]; then
                log_error "SSH key not found. Please specify the path to your OCI SSH key."
                read -p "SSH key path: " SSH_KEY
            fi
            
            chmod 600 "$SSH_KEY"
            
            log_info "Connecting to $OCI_IP..."
            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$SSH_KEY" ubuntu@$OCI_IP \
                "sudo cat /etc/rancher/k3s/k3s.yaml" > "$KUBECONFIG_FILE" 2>/dev/null || {
                log_warn "K3s not ready yet. Instances may still be provisioning."
                log_info "Falling back to Docker Compose deployment..."
                choice=2
            }
            
            if [ -f "$KUBECONFIG_FILE" ] && [ -s "$KUBECONFIG_FILE" ]; then
                # Update server address
                sed -i.bak "s/127.0.0.1/$OCI_IP/g" "$KUBECONFIG_FILE"
                log_info "Kubeconfig saved to $KUBECONFIG_FILE"
            fi
        fi
        
        if [ "$choice" = "1" ] && [ -f "$KUBECONFIG_FILE" ] && [ -s "$KUBECONFIG_FILE" ]; then
            export KUBECONFIG="$KUBECONFIG_FILE"
            
            # Test connection
            if kubectl cluster-info &>/dev/null; then
                log_info "Connected to K3s cluster!"
                
                # Deploy
                log_info "Applying Kubernetes manifests..."
                kubectl apply -f "$SCRIPT_DIR/k8s-manifests/"
                
                log_info "Waiting for deployments..."
                kubectl wait --for=condition=available --timeout=300s deployment --all -n temporal-cloud 2>/dev/null || true
                kubectl wait --for=condition=available --timeout=300s deployment --all -n temporal-system 2>/dev/null || true
                
                log_section "Deployment Complete!"
                echo ""
                kubectl get pods -n temporal-cloud
                kubectl get pods -n temporal-system
                echo ""
                log_info "Access your services:"
                echo "  Admin Portal:  https://app.$DOMAIN"
                echo "  Billing API:   https://api.$DOMAIN"
                echo "  Temporal UI:   https://temporal.$DOMAIN"
            else
                log_warn "Cannot connect to K3s. Falling back to Docker Compose..."
                choice=2
            fi
        fi
        ;;
esac

if [ "$choice" = "2" ]; then
    log_section "Deploying with Docker Compose"
    
    cd "$SCRIPT_DIR"
    
    # Build images
    log_info "Building Docker images..."
    docker-compose -f docker-compose.prod.yaml build
    
    # Start services
    log_info "Starting services..."
    docker-compose -f docker-compose.prod.yaml up -d
    
    # Wait for services
    log_info "Waiting for services to be ready..."
    sleep 10
    
    # Health check
    log_info "Running health checks..."
    for i in {1..30}; do
        if curl -s http://localhost:8082/health | grep -q "ok"; then
            break
        fi
        sleep 2
    done
    
    log_section "Deployment Complete!"
    echo ""
    docker-compose -f docker-compose.prod.yaml ps
    echo ""
    log_info "Access your services:"
    echo "  Admin Portal:  http://localhost:3000"
    echo "  Billing API:   http://localhost:8082"
    echo "  Temporal UI:   http://localhost:8080"
    echo "  Grafana:       http://localhost:3001"
fi

if [ "$choice" = "3" ]; then
    log_section "Building Docker Images"
    
    cd "$PROJECT_ROOT"
    
    REGISTRY="${DOCKER_REGISTRY:-local}"
    
    log_info "Building billing-service..."
    docker build -t $REGISTRY/billing-service:latest billing-service/
    
    log_info "Building admin-portal..."
    docker build -t $REGISTRY/admin-portal:latest admin-portal/
    
    log_info "Building usage-collector..."
    docker build -t $REGISTRY/usage-collector:latest usage-collector/
    
    log_section "Build Complete!"
    docker images | grep -E "(billing-service|admin-portal|usage-collector)"
fi

echo ""
log_info "Done!"
