#!/bin/bash
# Deploy Temporal Cloud to Kubernetes
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/k8s-manifests"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
        exit 1
    fi
    
    log_info "Connected to cluster: $(kubectl config current-context)"
}

# Build and push images
build_images() {
    log_info "Building Docker images..."
    
    # Get registry from environment or use default
    REGISTRY=${DOCKER_REGISTRY:-"ghcr.io/yourusername"}
    
    # Build billing service
    log_info "Building billing-service..."
    docker build -t $REGISTRY/billing-service:latest "$SCRIPT_DIR/../billing-service"
    docker push $REGISTRY/billing-service:latest
    
    # Build admin portal
    log_info "Building admin-portal..."
    docker build -t $REGISTRY/admin-portal:latest "$SCRIPT_DIR/../admin-portal"
    docker push $REGISTRY/admin-portal:latest
    
    log_info "Images pushed to $REGISTRY"
}

# Deploy to Kubernetes
deploy() {
    log_info "Deploying to Kubernetes..."
    
    # Apply manifests in order
    for manifest in "$MANIFESTS_DIR"/*.yaml; do
        log_info "Applying $(basename $manifest)..."
        kubectl apply -f "$manifest"
    done
    
    log_info "Waiting for deployments..."
    
    # Wait for postgres
    kubectl wait --for=condition=available --timeout=300s deployment/postgres -n temporal-cloud || true
    
    # Wait for temporal server
    kubectl wait --for=condition=available --timeout=300s deployment/temporal-server -n temporal-system || true
    
    # Wait for other services
    kubectl wait --for=condition=available --timeout=120s deployment/temporal-ui -n temporal-system || true
    kubectl wait --for=condition=available --timeout=120s deployment/billing-service -n temporal-cloud || true
    kubectl wait --for=condition=available --timeout=120s deployment/admin-portal -n temporal-cloud || true
}

# Show status
show_status() {
    log_info "Deployment Status:"
    echo ""
    
    echo "=== Pods ==="
    kubectl get pods -n temporal-cloud
    kubectl get pods -n temporal-system
    echo ""
    
    echo "=== Services ==="
    kubectl get svc -n temporal-cloud
    kubectl get svc -n temporal-system
    echo ""
    
    echo "=== Ingress ==="
    kubectl get ingress -n temporal-cloud
    kubectl get ingress -n temporal-system
    echo ""
    
    # Get external IP
    EXTERNAL_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    log_info "External IP: $EXTERNAL_IP"
    log_info ""
    log_info "Configure your DNS:"
    log_info "  app.yourdomain.com     -> $EXTERNAL_IP"
    log_info "  api.yourdomain.com     -> $EXTERNAL_IP"
    log_info "  temporal.yourdomain.com -> $EXTERNAL_IP"
    log_info "  grpc.yourdomain.com    -> $EXTERNAL_IP"
}

# Main
main() {
    case "${1:-deploy}" in
        build)
            check_prerequisites
            build_images
            ;;
        deploy)
            check_prerequisites
            deploy
            show_status
            ;;
        status)
            check_prerequisites
            show_status
            ;;
        all)
            check_prerequisites
            build_images
            deploy
            show_status
            ;;
        *)
            echo "Usage: $0 {build|deploy|status|all}"
            exit 1
            ;;
    esac
}

main "$@"
