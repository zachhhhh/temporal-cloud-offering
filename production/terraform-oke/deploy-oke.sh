#!/bin/bash
# Temporal Cloud - OKE Deployment Script
# Deploys OKE cluster and Temporal stack

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}==>${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    local missing=()
    
    command -v terraform >/dev/null 2>&1 || missing+=("terraform")
    command -v oci >/dev/null 2>&1 || missing+=("oci-cli")
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing+=("helm")
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        echo "Install with:"
        echo "  brew install terraform oci-cli kubectl helm"
        exit 1
    fi
    
    if [ ! -f "$SCRIPT_DIR/terraform.tfvars" ]; then
        log_error "terraform.tfvars not found"
        echo "Copy terraform.tfvars.example to terraform.tfvars and configure"
        exit 1
    fi
    
    log_info "All prerequisites met"
}

# Deploy OKE cluster
deploy_oke() {
    log_step "Deploying OKE cluster..."
    
    cd "$SCRIPT_DIR"
    
    terraform init
    terraform plan -out=tfplan
    
    echo ""
    read -p "Apply this plan? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply tfplan
    else
        log_warn "Deployment cancelled"
        exit 0
    fi
    
    log_info "OKE cluster deployed"
}

# Configure kubectl
configure_kubectl() {
    log_step "Configuring kubectl..."
    
    cd "$SCRIPT_DIR"
    
    CLUSTER_ID=$(terraform output -raw cluster_id)
    REGION=$(grep 'region' terraform.tfvars | cut -d'"' -f2)
    
    # Backup existing kubeconfig
    if [ -f ~/.kube/config ]; then
        cp ~/.kube/config ~/.kube/config.backup.$(date +%s)
    fi
    
    # Get kubeconfig from OKE
    oci ce cluster create-kubeconfig \
        --cluster-id "$CLUSTER_ID" \
        --file ~/.kube/config \
        --region "$REGION" \
        --token-version 2.0.0 \
        --kube-endpoint PUBLIC_ENDPOINT
    
    # Verify connection
    kubectl cluster-info
    kubectl get nodes
    
    log_info "kubectl configured"
}

# Deploy Temporal stack
deploy_temporal() {
    log_step "Deploying Temporal stack..."
    
    # Create namespace
    kubectl create namespace temporal-cloud --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply manifests
    kubectl apply -f "$PROJECT_ROOT/production/k8s-minimal/namespace.yaml" || true
    kubectl apply -f "$PROJECT_ROOT/production/k8s-minimal/postgres.yaml"
    kubectl apply -f "$PROJECT_ROOT/production/k8s-minimal/temporal.yaml"
    kubectl apply -f "$PROJECT_ROOT/production/k8s-minimal/billing.yaml"
    kubectl apply -f "$PROJECT_ROOT/production/k8s-minimal/admin-portal.yaml"
    
    log_info "Temporal stack deployed"
}

# Wait for pods
wait_for_pods() {
    log_step "Waiting for pods to be ready..."
    
    kubectl wait --for=condition=ready pod \
        -l app=postgresql \
        -n temporal-cloud \
        --timeout=300s || true
    
    kubectl wait --for=condition=ready pod \
        -l app=temporal \
        -n temporal-cloud \
        --timeout=300s || true
    
    kubectl get pods -n temporal-cloud
    
    log_info "Pods ready"
}

# Setup ingress
setup_ingress() {
    log_step "Setting up ingress..."
    
    # Install NGINX ingress controller
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --set controller.service.annotations."oci\.oraclecloud\.com/load-balancer-type"=lb \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape"=flexible \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape-flex-min"=10 \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/oci-load-balancer-shape-flex-max"=10
    
    # Wait for load balancer IP
    echo "Waiting for load balancer IP..."
    for i in {1..60}; do
        LB_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$LB_IP" ]; then
            break
        fi
        sleep 5
    done
    
    if [ -n "$LB_IP" ]; then
        log_info "Load Balancer IP: $LB_IP"
    else
        log_warn "Load balancer IP not yet assigned. Check with:"
        echo "  kubectl get svc ingress-nginx-controller -n ingress-nginx"
    fi
}

# Print access info
print_access_info() {
    log_step "Access Information"
    
    echo ""
    echo "=============================================="
    echo "  Temporal Cloud on OKE - Deployed!"
    echo "=============================================="
    echo ""
    
    LB_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    echo "Load Balancer IP: $LB_IP"
    echo ""
    echo "Services:"
    echo "  Admin Portal:  http://$LB_IP/"
    echo "  Temporal UI:   http://$LB_IP/temporal/"
    echo "  Billing API:   http://$LB_IP/api/"
    echo ""
    echo "Kubectl commands:"
    echo "  kubectl get pods -n temporal-cloud"
    echo "  kubectl logs -f deployment/temporal -n temporal-cloud"
    echo ""
    echo "To destroy:"
    echo "  cd $SCRIPT_DIR && terraform destroy"
    echo ""
}

# Destroy cluster
destroy() {
    log_step "Destroying OKE cluster..."
    
    cd "$SCRIPT_DIR"
    
    # Delete K8s resources first
    kubectl delete namespace temporal-cloud --ignore-not-found
    kubectl delete namespace ingress-nginx --ignore-not-found
    
    # Destroy Terraform resources
    terraform destroy -auto-approve
    
    log_info "OKE cluster destroyed"
}

# Main
case "${1:-deploy}" in
    deploy)
        check_prerequisites
        deploy_oke
        configure_kubectl
        deploy_temporal
        wait_for_pods
        setup_ingress
        print_access_info
        ;;
    kubectl)
        configure_kubectl
        ;;
    temporal)
        deploy_temporal
        wait_for_pods
        ;;
    ingress)
        setup_ingress
        ;;
    status)
        kubectl get pods -n temporal-cloud
        kubectl get svc -n temporal-cloud
        kubectl get svc -n ingress-nginx
        ;;
    destroy)
        destroy
        ;;
    *)
        echo "Usage: $0 {deploy|kubectl|temporal|ingress|status|destroy}"
        exit 1
        ;;
esac
