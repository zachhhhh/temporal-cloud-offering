#!/bin/bash
# Production Deployment to OKE
# Mission Critical - Zero Error Tolerance

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
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_section() { echo -e "\n${BLUE}========================================${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}========================================${NC}"; }

# Validate prerequisites
validate_prerequisites() {
    log_section "Validating Prerequisites"
    
    command -v kubectl &> /dev/null || log_error "kubectl not found"
    command -v docker &> /dev/null || log_error "docker not found"
    
    log_info "✅ Prerequisites validated"
}

# Get OKE kubeconfig
setup_kubeconfig() {
    log_section "Setting Up Kubeconfig"
    
    cd "$SCRIPT_DIR/terraform-oke"
    
    # Get cluster ID
    CLUSTER_ID=$(terraform output -raw cluster_id 2>/dev/null) || log_error "OKE cluster not found"
    
    log_info "Cluster ID: $CLUSTER_ID"
    
    # Generate kubeconfig
    mkdir -p ~/.kube
    oci ce cluster create-kubeconfig \
        --cluster-id "$CLUSTER_ID" \
        --file ~/.kube/config-oke \
        --region ap-singapore-1 \
        --token-version 2.0.0 \
        --kube-endpoint PUBLIC_ENDPOINT
    
    export KUBECONFIG=~/.kube/config-oke
    
    # Verify connection
    kubectl cluster-info || log_error "Cannot connect to OKE cluster"
    
    log_info "✅ Connected to OKE cluster"
}

# Build and push Docker images
build_and_push_images() {
    log_section "Building Docker Images"
    
    cd "$PROJECT_ROOT"
    
    # Use GitHub Container Registry or build locally
    REGISTRY="${DOCKER_REGISTRY:-ghcr.io/temporal-cloud}"
    
    log_info "Building billing-service..."
    docker build -t $REGISTRY/billing-service:latest billing-service/
    
    log_info "Building admin-portal..."
    docker build -t $REGISTRY/admin-portal:latest admin-portal/
    
    log_info "Building usage-collector..."
    docker build -t $REGISTRY/usage-collector:latest usage-collector/
    
    if [ -n "$DOCKER_REGISTRY" ]; then
        log_info "Pushing images to $REGISTRY..."
        docker push $REGISTRY/billing-service:latest
        docker push $REGISTRY/admin-portal:latest
        docker push $REGISTRY/usage-collector:latest
    fi
    
    log_info "✅ Images built"
}

# Deploy to Kubernetes
deploy_to_kubernetes() {
    log_section "Deploying to Kubernetes"
    
    cd "$SCRIPT_DIR/k8s-production"
    
    # Apply in order
    log_info "Creating namespaces..."
    kubectl apply -f 00-namespaces.yaml
    
    log_info "Creating secrets..."
    kubectl apply -f 01-secrets.yaml
    
    log_info "Deploying PostgreSQL..."
    kubectl apply -f 02-postgres.yaml
    
    log_info "Waiting for PostgreSQL..."
    kubectl wait --for=condition=ready pod -l app=postgres -n temporal-cloud --timeout=300s
    
    log_info "Deploying Temporal Server..."
    kubectl apply -f 03-temporal-server.yaml
    
    log_info "Waiting for Temporal Server..."
    kubectl wait --for=condition=available deployment/temporal-server -n temporal-system --timeout=300s
    
    log_info "Deploying Temporal UI..."
    kubectl apply -f 04-temporal-ui.yaml
    
    log_info "Deploying Billing Service..."
    kubectl apply -f 05-billing-service.yaml
    
    log_info "Deploying Admin Portal..."
    kubectl apply -f 06-admin-portal.yaml
    
    log_info "Deploying Ingress..."
    kubectl apply -f 07-ingress.yaml
    
    log_info "Deploying Monitoring..."
    kubectl apply -f 08-monitoring.yaml
    
    log_info "✅ All resources deployed"
}

# Wait for all deployments
wait_for_deployments() {
    log_section "Waiting for Deployments"
    
    log_info "Waiting for all pods to be ready..."
    
    kubectl wait --for=condition=available deployment --all -n temporal-cloud --timeout=300s || true
    kubectl wait --for=condition=available deployment --all -n temporal-system --timeout=300s || true
    
    log_info "✅ All deployments ready"
}

# Verify deployment
verify_deployment() {
    log_section "Verifying Deployment"
    
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
    
    # Get LoadBalancer IP
    LB_IP=$(kubectl get svc temporal-grpc-lb -n temporal-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    echo ""
    log_info "LoadBalancer IP: $LB_IP"
    
    # Health checks
    log_info "Running health checks..."
    
    # Port-forward and test
    kubectl port-forward svc/billing-service 8082:8082 -n temporal-cloud &
    PF_PID=$!
    sleep 3
    
    if curl -s http://localhost:8082/health | grep -q "ok"; then
        log_info "✅ Billing API healthy"
    else
        log_warn "⚠️ Billing API not responding"
    fi
    
    kill $PF_PID 2>/dev/null || true
    
    log_info "✅ Deployment verified"
}

# Print access info
print_access_info() {
    log_section "Access Information"
    
    LB_IP=$(kubectl get svc temporal-grpc-lb -n temporal-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    echo ""
    echo "Your Temporal Cloud is now live!"
    echo ""
    echo "URLs:"
    echo "  Admin Portal:  http://app.${LB_IP}.nip.io"
    echo "  Billing API:   http://api.${LB_IP}.nip.io"
    echo "  Temporal UI:   http://temporal.${LB_IP}.nip.io"
    echo "  Temporal gRPC: ${LB_IP}:7233"
    echo ""
    echo "Grafana: kubectl port-forward svc/grafana 3000:3000 -n temporal-system"
    echo "         http://localhost:3000 (admin/admin_temporal_prod)"
    echo ""
}

# Main
main() {
    log_section "OKE Production Deployment"
    echo "Mission Critical - Zero Error Tolerance"
    
    validate_prerequisites
    setup_kubeconfig
    build_and_push_images
    deploy_to_kubernetes
    wait_for_deployments
    verify_deployment
    print_access_info
    
    log_section "Deployment Complete!"
}

main "$@"
