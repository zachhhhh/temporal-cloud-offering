#!/bin/bash
set -e

# Temporal Cloud - Oracle Cloud Infrastructure Deployment
# This script deploys a complete K3s cluster with Temporal on OCI Free Tier

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  Temporal Cloud - OCI Deployment"
echo "=============================================="
echo ""

# Check prerequisites
check_prereqs() {
    echo "Checking prerequisites..."
    
    command -v terraform >/dev/null 2>&1 || { 
        echo "Installing Terraform..."
        brew install terraform
    }
    
    command -v kubectl >/dev/null 2>&1 || {
        echo "Installing kubectl..."
        brew install kubectl
    }
    
    command -v helm >/dev/null 2>&1 || {
        echo "Installing Helm..."
        brew install helm
    }
    
    command -v oci >/dev/null 2>&1 || {
        echo "Installing OCI CLI..."
        brew install oci-cli
    }
    
    echo "✓ All prerequisites installed"
}

# Deploy K3s cluster with Terraform
deploy_cluster() {
    echo ""
    echo "Step 1: Deploying K3s cluster with Terraform..."
    cd terraform-oci
    
    terraform init
    terraform plan -out=.tfplan
    
    echo ""
    echo "Review the plan above. Continue? (y/n)"
    read -r confirm
    if [ "$confirm" != "y" ]; then
        echo "Aborted."
        exit 1
    fi
    
    terraform apply .tfplan
    
    # Get outputs
    SERVER_IP=$(terraform output -raw k3s_servers_ips 2>/dev/null | tr -d '[]"' | cut -d',' -f1)
    LB_IP=$(terraform output -raw public_lb_ip 2>/dev/null)
    
    echo ""
    echo "✓ Cluster deployed!"
    echo "  Server IP: $SERVER_IP"
    echo "  Load Balancer IP: $LB_IP"
    
    cd ..
}

# Get kubeconfig from cluster
get_kubeconfig() {
    echo ""
    echo "Step 2: Fetching kubeconfig..."
    
    SERVER_IP=$(cd terraform-oci && terraform output -raw k3s_servers_ips 2>/dev/null | tr -d '[]"' | cut -d',' -f1)
    
    # Wait for SSH to be available
    echo "Waiting for server to be ready..."
    for i in {1..30}; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/oracle_temporal ubuntu@$SERVER_IP "echo ready" 2>/dev/null; then
            break
        fi
        echo "  Waiting... ($i/30)"
        sleep 10
    done
    
    # Copy kubeconfig
    mkdir -p ~/.kube
    scp -o StrictHostKeyChecking=no -i ~/.ssh/oracle_temporal ubuntu@$SERVER_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/config-oci
    
    # Update server address in kubeconfig
    LB_IP=$(cd terraform-oci && terraform output -raw public_lb_ip 2>/dev/null)
    sed -i '' "s/127.0.0.1/$LB_IP/g" ~/.kube/config-oci
    
    export KUBECONFIG=~/.kube/config-oci
    
    echo "✓ Kubeconfig saved to ~/.kube/config-oci"
    echo ""
    echo "Cluster nodes:"
    kubectl get nodes
}

# Deploy Temporal stack with Helm
deploy_temporal() {
    echo ""
    echo "Step 3: Deploying Temporal Cloud stack..."
    
    export KUBECONFIG=~/.kube/config-oci
    
    # Create namespace
    kubectl create namespace temporal-cloud --dry-run=client -o yaml | kubectl apply -f -
    
    # Add Bitnami repo for dependencies
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    
    # Update Helm dependencies
    cd helm/temporal-cloud
    helm dependency update
    cd ../..
    
    # Install Temporal Cloud
    helm upgrade --install temporal-cloud ./helm/temporal-cloud \
        --namespace temporal-cloud \
        --wait \
        --timeout 10m
    
    echo ""
    echo "✓ Temporal Cloud deployed!"
    echo ""
    echo "Pods:"
    kubectl get pods -n temporal-cloud
}

# Print access information
print_info() {
    echo ""
    echo "=============================================="
    echo "  Deployment Complete!"
    echo "=============================================="
    echo ""
    
    LB_IP=$(cd terraform-oci && terraform output -raw public_lb_ip 2>/dev/null)
    
    echo "Access your services:"
    echo ""
    echo "  Load Balancer IP: $LB_IP"
    echo ""
    echo "  Configure DNS (A records):"
    echo "    temporal.yourdomain.com -> $LB_IP"
    echo "    api.yourdomain.com      -> $LB_IP"
    echo "    cloud.yourdomain.com    -> $LB_IP"
    echo ""
    echo "  Or access directly:"
    echo "    http://$LB_IP (landing page)"
    echo ""
    echo "  Temporal gRPC endpoint:"
    echo "    $LB_IP:7233"
    echo ""
    echo "  kubectl access:"
    echo "    export KUBECONFIG=~/.kube/config-oci"
    echo "    kubectl get pods -n temporal-cloud"
    echo ""
    echo "  SSH to server:"
    echo "    ssh -i ~/.ssh/oracle_temporal ubuntu@<SERVER_IP>"
    echo ""
    echo "Cost: \$0/month (Oracle Always Free Tier)"
}

# Destroy cluster
destroy() {
    echo "Destroying cluster..."
    cd terraform-oci
    terraform destroy
    cd ..
    echo "✓ Cluster destroyed"
}

# Main
case "${1:-deploy}" in
    deploy)
        check_prereqs
        deploy_cluster
        get_kubeconfig
        deploy_temporal
        print_info
        ;;
    cluster)
        check_prereqs
        deploy_cluster
        get_kubeconfig
        ;;
    temporal)
        deploy_temporal
        print_info
        ;;
    destroy)
        destroy
        ;;
    *)
        echo "Usage: $0 {deploy|cluster|temporal|destroy}"
        exit 1
        ;;
esac
