#!/bin/bash
set -e

export SUPPRESS_LABEL_WARNING=True

# Configuration
TENANCY_OCID="ocid1.tenancy.oc1..aaaaaaaalbigkh7wajpf7ew4h3os6hkf2bif5ttsuql37lfinty6oz6mkokq"
COMPARTMENT_OCID="$TENANCY_OCID"  # Using root compartment
AD_NAME="ldIz:AP-SINGAPORE-1-AD-1"
IMAGE_OCID="ocid1.image.oc1.ap-singapore-1.aaaaaaaaabcgip2rouii76kkuwfymjfrjykmt6qeyi5k7bizrmdijftfcbsa"
SHAPE="VM.Standard.A1.Flex"
OCPUS=4
MEMORY_GB=24
DISPLAY_NAME="temporal-cloud"

echo "=== Oracle Cloud Free Tier - Temporal Cloud Deployment ==="
echo ""

# Generate SSH key if not exists
if [ ! -f ~/.ssh/oracle_temporal ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/oracle_temporal -N ""
fi
SSH_PUBLIC_KEY=$(cat ~/.ssh/oracle_temporal.pub)

# Step 1: Create VCN
echo "Step 1: Creating Virtual Cloud Network..."
VCN_RESULT=$(oci network vcn create \
    --compartment-id "$COMPARTMENT_OCID" \
    --cidr-blocks '["10.0.0.0/16"]' \
    --display-name "temporal-vcn" \
    --dns-label "temporalvcn" \
    --wait-for-state AVAILABLE \
    --output json 2>/dev/null)

VCN_OCID=$(echo "$VCN_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
echo "  VCN created: $VCN_OCID"

# Step 2: Create Internet Gateway
echo "Step 2: Creating Internet Gateway..."
IGW_RESULT=$(oci network internet-gateway create \
    --compartment-id "$COMPARTMENT_OCID" \
    --vcn-id "$VCN_OCID" \
    --display-name "temporal-igw" \
    --is-enabled true \
    --wait-for-state AVAILABLE \
    --output json 2>/dev/null)

IGW_OCID=$(echo "$IGW_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
echo "  Internet Gateway created: $IGW_OCID"

# Step 3: Create Route Table
echo "Step 3: Creating Route Table..."
RT_RESULT=$(oci network route-table create \
    --compartment-id "$COMPARTMENT_OCID" \
    --vcn-id "$VCN_OCID" \
    --display-name "temporal-rt" \
    --route-rules "[{\"destination\":\"0.0.0.0/0\",\"destinationType\":\"CIDR_BLOCK\",\"networkEntityId\":\"$IGW_OCID\"}]" \
    --wait-for-state AVAILABLE \
    --output json 2>/dev/null)

RT_OCID=$(echo "$RT_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
echo "  Route Table created: $RT_OCID"

# Step 4: Create Security List
echo "Step 4: Creating Security List..."
SL_RESULT=$(oci network security-list create \
    --compartment-id "$COMPARTMENT_OCID" \
    --vcn-id "$VCN_OCID" \
    --display-name "temporal-sl" \
    --egress-security-rules '[{"destination":"0.0.0.0/0","protocol":"all","isStateless":false}]' \
    --ingress-security-rules '[
        {"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":22,"max":22}}},
        {"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":80,"max":80}}},
        {"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":443,"max":443}}},
        {"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":6443,"max":6443}}},
        {"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":7233,"max":7239}}},
        {"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":8080,"max":8083}}},
        {"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":3000,"max":3001}}},
        {"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":9090,"max":9090}}}
    ]' \
    --wait-for-state AVAILABLE \
    --output json 2>/dev/null)

SL_OCID=$(echo "$SL_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
echo "  Security List created: $SL_OCID"

# Step 5: Create Subnet
echo "Step 5: Creating Subnet..."
SUBNET_RESULT=$(oci network subnet create \
    --compartment-id "$COMPARTMENT_OCID" \
    --vcn-id "$VCN_OCID" \
    --availability-domain "$AD_NAME" \
    --cidr-block "10.0.1.0/24" \
    --display-name "temporal-subnet" \
    --dns-label "temporalsub" \
    --route-table-id "$RT_OCID" \
    --security-list-ids "[\"$SL_OCID\"]" \
    --wait-for-state AVAILABLE \
    --output json 2>/dev/null)

SUBNET_OCID=$(echo "$SUBNET_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
echo "  Subnet created: $SUBNET_OCID"

# Step 6: Create Compute Instance (ARM - Free Tier)
echo "Step 6: Creating ARM Compute Instance (4 OCPU, 24GB RAM)..."
echo "  This may take a few minutes..."

INSTANCE_RESULT=$(oci compute instance launch \
    --compartment-id "$COMPARTMENT_OCID" \
    --availability-domain "$AD_NAME" \
    --shape "$SHAPE" \
    --shape-config "{\"ocpus\":$OCPUS,\"memoryInGBs\":$MEMORY_GB}" \
    --image-id "$IMAGE_OCID" \
    --subnet-id "$SUBNET_OCID" \
    --display-name "$DISPLAY_NAME" \
    --assign-public-ip true \
    --ssh-authorized-keys-file ~/.ssh/oracle_temporal.pub \
    --wait-for-state RUNNING \
    --output json 2>/dev/null)

INSTANCE_OCID=$(echo "$INSTANCE_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
echo "  Instance created: $INSTANCE_OCID"

# Get public IP
sleep 10
VNIC_ATTACHMENTS=$(oci compute vnic-attachment list \
    --compartment-id "$COMPARTMENT_OCID" \
    --instance-id "$INSTANCE_OCID" \
    --output json 2>/dev/null)

VNIC_OCID=$(echo "$VNIC_ATTACHMENTS" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['vnic-id'])")

VNIC_INFO=$(oci network vnic get --vnic-id "$VNIC_OCID" --output json 2>/dev/null)
PUBLIC_IP=$(echo "$VNIC_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['public-ip'])")

echo ""
echo "=== Instance Created Successfully ==="
echo "Public IP: $PUBLIC_IP"
echo "SSH Key: ~/.ssh/oracle_temporal"
echo ""
echo "Connect with: ssh -i ~/.ssh/oracle_temporal ubuntu@$PUBLIC_IP"
echo ""

# Save instance info
cat > oracle-instance.env << EOF
INSTANCE_OCID=$INSTANCE_OCID
VCN_OCID=$VCN_OCID
SUBNET_OCID=$SUBNET_OCID
PUBLIC_IP=$PUBLIC_IP
SSH_KEY=~/.ssh/oracle_temporal
EOF

echo "Instance info saved to oracle-instance.env"
echo ""
echo "Waiting 60 seconds for instance to fully boot..."
sleep 60

echo ""
echo "=== Installing K3s and Temporal Stack ==="
ssh -o StrictHostKeyChecking=no -i ~/.ssh/oracle_temporal ubuntu@$PUBLIC_IP 'bash -s' << 'REMOTE_SCRIPT'
set -e

echo "Updating system..."
sudo apt-get update
sudo apt-get install -y curl wget git

echo "Installing K3s..."
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

echo "Waiting for K3s to be ready..."
sleep 30
sudo kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "K3s installed successfully!"
sudo kubectl get nodes
REMOTE_SCRIPT

echo ""
echo "=== Deploying Temporal Stack ==="

# Copy deployment files
scp -o StrictHostKeyChecking=no -i ~/.ssh/oracle_temporal -r ../k8s-minimal ubuntu@$PUBLIC_IP:~/

ssh -o StrictHostKeyChecking=no -i ~/.ssh/oracle_temporal ubuntu@$PUBLIC_IP 'bash -s' << 'DEPLOY_SCRIPT'
set -e

cd ~/k8s-minimal

echo "Creating namespace..."
sudo kubectl apply -f namespace.yaml

echo "Deploying PostgreSQL..."
sudo kubectl apply -f postgres.yaml

echo "Deploying Redis..."
sudo kubectl apply -f redis.yaml

echo "Waiting for databases..."
sleep 30
sudo kubectl wait --for=condition=Ready pod -l app=postgres -n temporal-cloud --timeout=300s || true

echo "Deploying Temporal..."
sudo kubectl apply -f temporal.yaml

echo "Deploying Billing Service..."
sudo kubectl apply -f billing.yaml

echo "Deploying Admin Portal..."
sudo kubectl apply -f admin-portal.yaml

echo "Deploying Ingress..."
sudo kubectl apply -f ingress.yaml

echo ""
echo "=== Deployment Complete ==="
sudo kubectl get pods -n temporal-cloud
sudo kubectl get svc -n temporal-cloud
DEPLOY_SCRIPT

echo ""
echo "=========================================="
echo "  TEMPORAL CLOUD DEPLOYED SUCCESSFULLY!"
echo "=========================================="
echo ""
echo "Public IP: $PUBLIC_IP"
echo ""
echo "Access your services:"
echo "  Admin Portal:  http://$PUBLIC_IP:3000"
echo "  Temporal UI:   http://$PUBLIC_IP:8080"
echo "  Billing API:   http://$PUBLIC_IP:8082"
echo ""
echo "SSH access: ssh -i ~/.ssh/oracle_temporal ubuntu@$PUBLIC_IP"
echo ""
