#!/bin/bash
set -e

echo "=== Temporal Cloud Production Deployment ==="

# Check prerequisites
command -v hetzner-k3s >/dev/null 2>&1 || { echo "hetzner-k3s not found. Install: brew install vitobotta/tap/hetzner_k3s"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }

# Check for Hetzner token
if [ -z "$HCLOUD_TOKEN" ]; then
    echo "Error: HCLOUD_TOKEN environment variable not set"
    echo "Get your token from: https://console.hetzner.cloud/ -> Project -> Security -> API Tokens"
    exit 1
fi

# Update cluster config with token
sed -i.bak "s/<YOUR_HETZNER_API_TOKEN>/$HCLOUD_TOKEN/" hetzner/cluster.yaml

echo ""
echo "Step 1: Creating Kubernetes cluster on Hetzner..."
cd hetzner
hetzner-k3s create --config cluster.yaml
cd ..

export KUBECONFIG=./hetzner/kubeconfig

echo ""
echo "Step 2: Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo ""
echo "Step 3: Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=120s

echo ""
echo "Step 4: Installing ingress-nginx..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
kubectl wait --for=condition=Available deployment --all -n ingress-nginx --timeout=120s

echo ""
echo "Step 5: Deploying Temporal Cloud stack..."
kubectl apply -f k8s/namespace.yaml

echo "⚠️  IMPORTANT: Edit k8s/secrets.yaml with your actual secrets before continuing!"
echo "Press Enter when ready..."
read

kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/elasticsearch.yaml
kubectl apply -f k8s/redis.yaml
kubectl apply -f k8s/prometheus.yaml

echo ""
echo "Waiting for databases to be ready..."
kubectl wait --for=condition=Ready pod -l app=postgres -n temporal-cloud --timeout=300s
kubectl wait --for=condition=Ready pod -l app=elasticsearch -n temporal-cloud --timeout=300s

kubectl apply -f k8s/temporal.yaml
kubectl apply -f k8s/billing.yaml
kubectl apply -f k8s/admin-portal.yaml

echo ""
echo "Step 6: Configuring ingress..."
echo "⚠️  Edit k8s/ingress.yaml with your domain names before continuing!"
echo "Press Enter when ready..."
read

kubectl apply -f k8s/ingress.yaml

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Get your Load Balancer IP:"
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""
echo ""
echo "Configure your DNS:"
echo "  cloud.yourdomain.com    -> <LOAD_BALANCER_IP>"
echo "  temporal.yourdomain.com -> <LOAD_BALANCER_IP>"
echo "  api.yourdomain.com      -> <LOAD_BALANCER_IP>"
echo ""
echo "Check status:"
echo "  kubectl get pods -n temporal-cloud"
echo "  kubectl get ingress -n temporal-cloud"
