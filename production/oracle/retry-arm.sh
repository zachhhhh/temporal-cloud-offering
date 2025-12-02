#!/bin/bash
# Retry ARM instance creation until successful
# ARM instances are in high demand - this script keeps trying

set -e

COMPARTMENT_OCID="ocid1.tenancy.oc1..aaaaaaaalbigkh7wajpf7ew4h3os6hkf2bif5ttsuql37lfinty6oz6mkokq"
AD="ldIz:AP-SINGAPORE-1-AD-1"
SUBNET_OCID="ocid1.subnet.oc1.ap-singapore-1.aaaaaaaazjtikjubfkewtwr2slt6ytfayuuxxkocibvolyb3i2kwoqjmgkcq"
IMAGE_OCID="ocid1.image.oc1.ap-singapore-1.aaaaaaaaggp6h5vvqqrisqfdyqj4irgmqjd5fs56mo2ctqrr5snx3okv7yka"
SSH_KEY="$HOME/.ssh/oracle_temporal.pub"

# ARM config - max free tier
OCPUS=4
MEMORY_GB=24

export SUPPRESS_LABEL_WARNING=True

echo "=============================================="
echo "  ARM Instance Retry Script"
echo "=============================================="
echo ""
echo "Trying to create: VM.Standard.A1.Flex"
echo "  OCPUs: $OCPUS"
echo "  Memory: ${MEMORY_GB}GB"
echo ""
echo "This will keep trying every 5 minutes until successful."
echo "Press Ctrl+C to stop."
echo ""

attempt=1
while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt $attempt..."
    
    result=$(oci compute instance launch \
        --compartment-id "$COMPARTMENT_OCID" \
        --availability-domain "$AD" \
        --shape "VM.Standard.A1.Flex" \
        --shape-config "{\"ocpus\":$OCPUS,\"memoryInGBs\":$MEMORY_GB}" \
        --image-id "$IMAGE_OCID" \
        --subnet-id "$SUBNET_OCID" \
        --display-name "temporal-cloud-arm" \
        --assign-public-ip true \
        --ssh-authorized-keys-file "$SSH_KEY" 2>&1) || true
    
    if echo "$result" | grep -q "Out of host capacity"; then
        echo "  ❌ Out of capacity. Retrying in 5 minutes..."
        sleep 300
        ((attempt++))
    elif echo "$result" | grep -q '"lifecycle-state"'; then
        echo ""
        echo "=============================================="
        echo "  ✅ SUCCESS! ARM instance created!"
        echo "=============================================="
        echo ""
        echo "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)['data']
print(f\"Instance ID: {data['id']}\")
print(f\"Shape: {data['shape']}\")
print(f\"OCPUs: {data['shape-config']['ocpus']}\")
print(f\"Memory: {data['shape-config']['memory-in-gbs']}GB\")
"
        
        # Wait for IP
        echo ""
        echo "Waiting for public IP..."
        sleep 60
        
        instance_id=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
        
        vnic_info=$(oci compute instance list-vnics --instance-id "$instance_id" 2>/dev/null)
        public_ip=$(echo "$vnic_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['public-ip'])")
        
        echo "Public IP: $public_ip"
        echo ""
        echo "Next steps:"
        echo "  1. SSH: ssh -i ~/.ssh/oracle_temporal ubuntu@$public_ip"
        echo "  2. Run: ./setup-k3s-arm.sh $public_ip"
        
        # Save to file
        echo "ARM_INSTANCE_OCID=$instance_id" > arm-instance.env
        echo "ARM_PUBLIC_IP=$public_ip" >> arm-instance.env
        echo "ARM_OCPUS=$OCPUS" >> arm-instance.env
        echo "ARM_MEMORY_GB=$MEMORY_GB" >> arm-instance.env
        
        exit 0
    else
        echo "  ⚠️ Unexpected response:"
        echo "$result" | head -20
        echo "  Retrying in 5 minutes..."
        sleep 300
        ((attempt++))
    fi
done
