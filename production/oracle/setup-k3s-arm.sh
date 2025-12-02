#!/bin/bash
# Setup K3s on ARM instance with full Temporal stack
# Usage: ./setup-k3s-arm.sh <PUBLIC_IP>

set -e

PUBLIC_IP="${1:-}"
if [ -z "$PUBLIC_IP" ]; then
    if [ -f arm-instance.env ]; then
        source arm-instance.env
        PUBLIC_IP="$ARM_PUBLIC_IP"
    else
        echo "Usage: $0 <PUBLIC_IP>"
        exit 1
    fi
fi

SSH_KEY="$HOME/.ssh/oracle_temporal"

echo "=============================================="
echo "  K3s Setup on ARM Instance"
echo "=============================================="
echo "  IP: $PUBLIC_IP"
echo "  Expected: 4 OCPU, 24GB RAM"
echo ""

# Wait for SSH
echo "Waiting for SSH..."
for i in {1..30}; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$SSH_KEY" ubuntu@"$PUBLIC_IP" "echo ready" 2>/dev/null; then
        break
    fi
    echo "  Waiting... ($i/30)"
    sleep 10
done

echo ""
echo "Step 1: System setup..."
ssh -i "$SSH_KEY" ubuntu@"$PUBLIC_IP" 'bash -s' << 'REMOTE'
set -e

# Update system
sudo apt-get update
sudo apt-get install -y curl wget git

# Open firewall ports
sudo iptables -I INPUT 5 -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 5 -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT 5 -p tcp --dport 6443 -j ACCEPT
sudo iptables -I INPUT 5 -p tcp --dport 7233 -j ACCEPT
sudo iptables -I INPUT 5 -p tcp --dport 8080 -j ACCEPT
sudo iptables -I INPUT 5 -p tcp --dport 3000 -j ACCEPT
sudo iptables -I INPUT 5 -p tcp --dport 9090 -j ACCEPT
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save

echo "System ready!"
REMOTE

echo ""
echo "Step 2: Installing K3s..."
ssh -i "$SSH_KEY" ubuntu@"$PUBLIC_IP" 'bash -s' << 'REMOTE'
set -e

# Install K3s
curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --disable servicelb

# Wait for K3s
echo "Waiting for K3s to be ready..."
sleep 30
sudo kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "K3s installed!"
sudo kubectl get nodes
REMOTE

echo ""
echo "Step 3: Installing Helm..."
ssh -i "$SSH_KEY" ubuntu@"$PUBLIC_IP" 'bash -s' << 'REMOTE'
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
REMOTE

echo ""
echo "Step 4: Deploying Temporal stack..."
ssh -i "$SSH_KEY" ubuntu@"$PUBLIC_IP" 'bash -s' << 'REMOTE'
set -e

# Create namespace
sudo kubectl create namespace temporal-cloud --dry-run=client -o yaml | sudo kubectl apply -f -

# Deploy PostgreSQL
cat << 'EOF' | sudo kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: temporal-cloud
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: temporal-cloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15-alpine
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_USER
              value: temporal
            - name: POSTGRES_PASSWORD
              value: temporal123
            - name: POSTGRES_DB
              value: temporal
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "2Gi"
              cpu: "1000m"
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: temporal-cloud
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
EOF

echo "Waiting for PostgreSQL..."
sudo kubectl wait --for=condition=Ready pod -l app=postgres -n temporal-cloud --timeout=300s

# Deploy Temporal Server
cat << 'EOF' | sudo kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: temporal
  namespace: temporal-cloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app: temporal
  template:
    metadata:
      labels:
        app: temporal
    spec:
      containers:
        - name: temporal
          image: temporalio/auto-setup:latest
          ports:
            - containerPort: 7233
            - containerPort: 7234
            - containerPort: 7235
            - containerPort: 7239
          env:
            - name: DB
              value: postgres12
            - name: DB_PORT
              value: "5432"
            - name: POSTGRES_USER
              value: temporal
            - name: POSTGRES_PWD
              value: temporal123
            - name: POSTGRES_SEEDS
              value: postgres.temporal-cloud.svc.cluster.local
          resources:
            requests:
              memory: "1Gi"
              cpu: "500m"
            limits:
              memory: "4Gi"
              cpu: "2000m"
---
apiVersion: v1
kind: Service
metadata:
  name: temporal
  namespace: temporal-cloud
spec:
  type: NodePort
  selector:
    app: temporal
  ports:
    - name: grpc
      port: 7233
      targetPort: 7233
      nodePort: 30233
EOF

# Deploy Temporal UI
cat << 'EOF' | sudo kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: temporal-ui
  namespace: temporal-cloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app: temporal-ui
  template:
    metadata:
      labels:
        app: temporal-ui
    spec:
      containers:
        - name: temporal-ui
          image: temporalio/ui:latest
          ports:
            - containerPort: 8080
          env:
            - name: TEMPORAL_ADDRESS
              value: temporal.temporal-cloud.svc.cluster.local:7233
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: temporal-ui
  namespace: temporal-cloud
spec:
  type: NodePort
  selector:
    app: temporal-ui
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30080
EOF

# Deploy Billing API
cat << 'EOF' | sudo kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: billing-code
  namespace: temporal-cloud
data:
  server.py: |
    from http.server import HTTPServer, BaseHTTPRequestHandler
    import json
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            if self.path == '/health':
                self.wfile.write(json.dumps({"status": "ok"}).encode())
            elif '/usage' in self.path:
                self.wfile.write(json.dumps({"total_actions": 0, "estimated_cost_cents": 0}).encode())
            elif '/namespaces' in self.path:
                self.wfile.write(json.dumps([{"id": "1", "name": "default", "status": "active"}]).encode())
            else:
                self.wfile.write(json.dumps({"path": self.path}).encode())
        def log_message(self, format, *args): pass
    print("Billing API on :8082")
    HTTPServer(('0.0.0.0', 8082), Handler).serve_forever()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing
  namespace: temporal-cloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app: billing
  template:
    metadata:
      labels:
        app: billing
    spec:
      containers:
        - name: billing
          image: python:3.11-alpine
          command: ["python", "/app/server.py"]
          ports:
            - containerPort: 8082
          volumeMounts:
            - name: code
              mountPath: /app
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "200m"
      volumes:
        - name: code
          configMap:
            name: billing-code
---
apiVersion: v1
kind: Service
metadata:
  name: billing
  namespace: temporal-cloud
spec:
  type: NodePort
  selector:
    app: billing
  ports:
    - port: 8082
      targetPort: 8082
      nodePort: 30082
EOF

# Deploy Nginx Ingress
sudo kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/baremetal/deploy.yaml

echo ""
echo "Waiting for all pods..."
sleep 30
sudo kubectl get pods -n temporal-cloud
sudo kubectl get pods -n ingress-nginx
REMOTE

echo ""
echo "Step 5: Getting kubeconfig..."
mkdir -p ~/.kube
scp -i "$SSH_KEY" ubuntu@"$PUBLIC_IP":/etc/rancher/k3s/k3s.yaml ~/.kube/config-oci-arm
sed -i '' "s/127.0.0.1/$PUBLIC_IP/g" ~/.kube/config-oci-arm

echo ""
echo "=============================================="
echo "  ✅ K3s Temporal Stack Deployed!"
echo "=============================================="
echo ""
echo "Access:"
echo "  Temporal UI:   http://$PUBLIC_IP:30080"
echo "  Billing API:   http://$PUBLIC_IP:30082/health"
echo "  Temporal gRPC: $PUBLIC_IP:30233"
echo ""
echo "kubectl:"
echo "  export KUBECONFIG=~/.kube/config-oci-arm"
echo "  kubectl get pods -n temporal-cloud"
echo ""
echo "SSH:"
echo "  ssh -i ~/.ssh/oracle_temporal ubuntu@$PUBLIC_IP"
echo ""
