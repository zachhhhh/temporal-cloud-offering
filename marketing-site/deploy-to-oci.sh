#!/bin/bash
# Deploy Marketing Site to Oracle Cloud Infrastructure (OCI)
# This script builds and deploys the marketing site to the K3s cluster on OCI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-oci}"
NAMESPACE="temporal-cloud"
IMAGE_NAME="temporal-cloud-marketing"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-ghcr.io/temporalio}"

echo "=== Temporal Cloud Marketing Site Deployment ==="
echo "Kubeconfig: $KUBECONFIG"
echo "Namespace: $NAMESPACE"
echo "Image: $REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
echo ""

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        echo "ERROR: docker is not installed"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo "ERROR: kubectl is not installed"
        exit 1
    fi
    
    if [ ! -f "$KUBECONFIG" ]; then
        echo "ERROR: Kubeconfig not found at $KUBECONFIG"
        echo "Please copy the kubeconfig from the K3s server:"
        echo "  scp -i ~/.ssh/oracle_temporal ubuntu@<SERVER_IP>:/etc/rancher/k3s/k3s.yaml ~/.kube/config-oci"
        exit 1
    fi
    
    echo "Prerequisites OK"
}

# Build Docker image
build_image() {
    echo ""
    echo "=== Building Docker image ==="
    cd "$SCRIPT_DIR"
    
    docker build -t "$REGISTRY/$IMAGE_NAME:$IMAGE_TAG" .
    
    echo "Build complete: $REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
}

# Push to registry (optional - for remote registries)
push_image() {
    echo ""
    echo "=== Pushing image to registry ==="
    
    docker push "$REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
    
    echo "Push complete"
}

# Deploy to Kubernetes
deploy_to_k8s() {
    echo ""
    echo "=== Deploying to Kubernetes ==="
    
    # Ensure namespace exists
    kubectl --kubeconfig="$KUBECONFIG" create namespace "$NAMESPACE" --dry-run=client -o yaml | \
        kubectl --kubeconfig="$KUBECONFIG" apply -f -
    
    # Apply the marketing site manifest
    kubectl --kubeconfig="$KUBECONFIG" apply -f "$PROJECT_ROOT/production/k8s-manifests/09-marketing-site.yaml"
    
    # Wait for deployment
    echo "Waiting for deployment to be ready..."
    kubectl --kubeconfig="$KUBECONFIG" -n "$NAMESPACE" rollout status deployment/marketing-site --timeout=300s
    
    echo "Deployment complete!"
}

# Get deployment status
get_status() {
    echo ""
    echo "=== Deployment Status ==="
    
    kubectl --kubeconfig="$KUBECONFIG" -n "$NAMESPACE" get pods -l app=marketing-site
    echo ""
    kubectl --kubeconfig="$KUBECONFIG" -n "$NAMESPACE" get svc marketing-site
    echo ""
    kubectl --kubeconfig="$KUBECONFIG" -n "$NAMESPACE" get ingress marketing-site-ingress
}

# Main
main() {
    case "${1:-deploy}" in
        build)
            check_prerequisites
            build_image
            ;;
        push)
            push_image
            ;;
        deploy)
            check_prerequisites
            deploy_to_k8s
            get_status
            ;;
        all)
            check_prerequisites
            build_image
            push_image
            deploy_to_k8s
            get_status
            ;;
        status)
            get_status
            ;;
        *)
            echo "Usage: $0 {build|push|deploy|all|status}"
            echo ""
            echo "Commands:"
            echo "  build   - Build Docker image locally"
            echo "  push    - Push image to registry"
            echo "  deploy  - Deploy to Kubernetes cluster"
            echo "  all     - Build, push, and deploy"
            echo "  status  - Show deployment status"
            exit 1
            ;;
    esac
}

main "$@"
