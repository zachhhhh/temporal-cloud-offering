#!/bin/bash
# One-Click Deployment for Temporal Cloud
# Uses official Temporal Helm charts from upstream
# Minimal cost configuration for 0 customers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_section() { echo -e "\n${BLUE}========================================${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}========================================${NC}"; }

show_help() {
    echo "Temporal Cloud - One-Click Deployment"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  local     Deploy locally with Docker Compose"
    echo "  oke       Deploy to OCI Kubernetes Engine"
    echo "  status    Show deployment status"
    echo "  destroy   Tear down deployment"
    echo "  backup    Create backup"
    echo "  restore   Restore from backup"
    echo ""
}

deploy_local() {
    log_section "Deploying Locally"
    
    cd "$SCRIPT_DIR/deploy"
    docker-compose up -d
    
    log_info "Waiting for services..."
    sleep 30
    
    log_info "Running health checks..."
    curl -s http://localhost:8082/health || log_warn "Billing API not ready"
    
    log_section "Local Deployment Complete"
    echo ""
    echo "Services:"
    echo "  Admin Portal:  http://localhost:3000"
    echo "  Billing API:   http://localhost:8082"
    echo "  Temporal UI:   http://localhost:8080"
    echo "  Temporal gRPC: localhost:7233"
    echo ""
}

deploy_oke() {
    log_section "Deploying to OKE"
    
    # Check prerequisites
    command -v kubectl &> /dev/null || log_error "kubectl not found"
    command -v helm &> /dev/null || log_error "helm not found"
    command -v oci &> /dev/null || log_error "OCI CLI not found"
    
    # Get kubeconfig
    log_info "Getting OKE kubeconfig..."
    CLUSTER_ID=$(cd "$SCRIPT_DIR/production/terraform-oke" && terraform output -raw cluster_id 2>/dev/null) || log_error "OKE cluster not found"
    
    oci ce cluster create-kubeconfig \
        --cluster-id "$CLUSTER_ID" \
        --file ~/.kube/config-oke \
        --region ap-singapore-1 \
        --token-version 2.0.0 \
        --kube-endpoint PUBLIC_ENDPOINT
    
    export KUBECONFIG=~/.kube/config-oke
    
    # Verify connection
    kubectl cluster-info || log_error "Cannot connect to OKE"
    
    # Create namespace
    kubectl create namespace temporal --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy PostgreSQL
    log_info "Deploying PostgreSQL..."
    kubectl apply -f "$SCRIPT_DIR/production/oke-minimal/postgres-minimal.yaml"
    kubectl wait --for=condition=ready pod -l app=postgres -n temporal --timeout=300s
    
    # Add Temporal Helm repo (official upstream)
    log_info "Adding Temporal Helm repo..."
    helm repo add temporal https://go.temporal.io/helm-charts
    helm repo update
    
    # Deploy Temporal using official chart
    log_info "Deploying Temporal (official Helm chart)..."
    helm upgrade --install temporal temporal/temporal \
        --namespace temporal \
        -f "$SCRIPT_DIR/production/oke-minimal/values-minimal.yaml" \
        --wait --timeout 10m
    
    # Deploy autoscaling
    log_info "Deploying autoscaling..."
    kubectl apply -f "$SCRIPT_DIR/production/oke-minimal/autoscaling.yaml"
    
    # Deploy disaster recovery
    log_info "Setting up disaster recovery..."
    kubectl apply -f "$SCRIPT_DIR/production/disaster-recovery/backup.yaml"
    
    log_section "OKE Deployment Complete"
    
    # Get external IP
    LB_IP=$(kubectl get svc temporal-frontend -n temporal -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    echo ""
    echo "Temporal Server: $LB_IP:7233"
    echo ""
    echo "To access Temporal UI, run:"
    echo "  kubectl port-forward svc/temporal-web 8080:8080 -n temporal"
    echo ""
}

show_status() {
    log_section "Deployment Status"
    
    echo "=== Local (Docker) ==="
    docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | grep temporal || echo "Not running"
    
    echo ""
    echo "=== OKE (Kubernetes) ==="
    if [ -f ~/.kube/config-oke ]; then
        export KUBECONFIG=~/.kube/config-oke
        kubectl get pods -n temporal 2>/dev/null || echo "Not connected"
    else
        echo "Not configured"
    fi
}

destroy() {
    log_section "Destroying Deployment"
    
    read -p "Are you sure? This will delete all data. (yes/no): " confirm
    [ "$confirm" != "yes" ] && exit 0
    
    # Local
    cd "$SCRIPT_DIR/deploy"
    docker-compose down -v 2>/dev/null || true
    
    # OKE
    if [ -f ~/.kube/config-oke ]; then
        export KUBECONFIG=~/.kube/config-oke
        helm uninstall temporal -n temporal 2>/dev/null || true
        kubectl delete namespace temporal 2>/dev/null || true
    fi
    
    log_info "Deployment destroyed"
}

backup() {
    log_section "Creating Backup"
    
    BACKUP_DIR="$SCRIPT_DIR/backups"
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/temporal-$(date +%Y%m%d-%H%M%S).sql.gz"
    
    # Local backup
    docker exec temporal-postgres pg_dumpall -U temporal | gzip > "$BACKUP_FILE"
    
    log_info "Backup created: $BACKUP_FILE"
}

restore() {
    log_section "Restoring from Backup"
    
    BACKUP_FILE="${1:-$(ls -t "$SCRIPT_DIR/backups"/*.sql.gz 2>/dev/null | head -1)}"
    [ -z "$BACKUP_FILE" ] && log_error "No backup file found"
    
    log_info "Restoring from: $BACKUP_FILE"
    gunzip -c "$BACKUP_FILE" | docker exec -i temporal-postgres psql -U temporal
    
    log_info "Restore complete"
}

# Main
case "${1:-help}" in
    local)   deploy_local ;;
    oke)     deploy_oke ;;
    status)  show_status ;;
    destroy) destroy ;;
    backup)  backup ;;
    restore) restore "$2" ;;
    *)       show_help ;;
esac
