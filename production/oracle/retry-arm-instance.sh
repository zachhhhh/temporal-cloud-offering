#!/bin/bash
# Oracle Cloud ARM Instance Retry Script
# Keeps trying to create an ARM A1 instance until capacity is available
#
# Usage: ./retry-arm-instance.sh [--once]
#   --once: Try once and exit (for cron jobs)
#
# Run as cron job every 5 minutes:
#   */5 * * * * /path/to/retry-arm-instance.sh --once >> /tmp/arm-retry.log 2>&1

set -e
export SUPPRESS_LABEL_WARNING=True

# Configuration
COMPARTMENT_OCID="ocid1.tenancy.oc1..aaaaaaaalbigkh7wajpf7ew4h3os6hkf2bif5ttsuql37lfinty6oz6mkokq"
AD_NAME="ldIz:AP-SINGAPORE-1-AD-1"
IMAGE_OCID="ocid1.image.oc1.ap-singapore-1.aaaaaaaaggp6h5vvqqrisqfdyqj4irgmqjd5fs56mo2ctqrr5snx3okv7yka"
SUBNET_OCID="ocid1.subnet.oc1.ap-singapore-1.aaaaaaaazjtikjubfkewtwr2slt6ytfayuuxxkocibvolyb3i2kwoqjmgkcq"
SSH_KEY_FILE="$HOME/.ssh/oracle_temporal.pub"
DISPLAY_NAME="temporal-k3s"
OCPUS=4
MEMORY_GB=24

# Retry settings
MAX_RETRIES=288  # 24 hours at 5-minute intervals
RETRY_INTERVAL=300  # 5 minutes

ONCE_MODE=false
if [ "$1" == "--once" ]; then
    ONCE_MODE=true
    MAX_RETRIES=1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_existing_arm() {
    # Check if ARM instance already exists
    EXISTING=$(oci compute instance list \
        --compartment-id "$COMPARTMENT_OCID" \
        --query "data[?shape=='VM.Standard.A1.Flex' && \"lifecycle-state\"=='RUNNING'].{name:\"display-name\",id:id}" \
        --output json 2>/dev/null)
    
    if [ "$(echo "$EXISTING" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))')" -gt 0 ]; then
        log "ARM instance already exists!"
        echo "$EXISTING" | python3 -c 'import sys,json; data=json.load(sys.stdin); print(f"  Name: {data[0][\"name\"]}, ID: {data[0][\"id\"]}")'
        return 0
    fi
    return 1
}

create_arm_instance() {
    log "Attempting to create ARM A1 instance (${OCPUS} OCPU, ${MEMORY_GB}GB RAM)..."
    
    RESULT=$(oci compute instance launch \
        --compartment-id "$COMPARTMENT_OCID" \
        --availability-domain "$AD_NAME" \
        --shape VM.Standard.A1.Flex \
        --shape-config "{\"ocpus\":$OCPUS,\"memoryInGBs\":$MEMORY_GB}" \
        --image-id "$IMAGE_OCID" \
        --subnet-id "$SUBNET_OCID" \
        --display-name "$DISPLAY_NAME" \
        --assign-public-ip true \
        --ssh-authorized-keys-file "$SSH_KEY_FILE" \
        --output json 2>&1)
    
    if echo "$RESULT" | grep -q "Out of host capacity"; then
        log "Out of capacity. Will retry..."
        return 1
    elif echo "$RESULT" | grep -q "ServiceError"; then
        log "Error: $(echo "$RESULT" | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"message\", \"Unknown error\"))' 2>/dev/null || echo "$RESULT")"
        return 1
    else
        log "SUCCESS! Instance created!"
        INSTANCE_ID=$(echo "$RESULT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')
        log "Instance ID: $INSTANCE_ID"
        
        # Wait for instance to get public IP
        sleep 30
        PUBLIC_IP=$(oci compute instance list-vnics \
            --instance-id "$INSTANCE_ID" \
            --query 'data[0]."public-ip"' \
            --raw-output 2>/dev/null)
        
        log "Public IP: $PUBLIC_IP"
        log ""
        log "=== ARM Instance Created Successfully ==="
        log "SSH: ssh -i ~/.ssh/oracle_temporal ubuntu@$PUBLIC_IP"
        log ""
        log "Next steps:"
        log "1. SSH into the instance"
        log "2. Install K3s: curl -sfL https://get.k3s.io | sh -"
        log "3. Deploy Temporal stack"
        
        # Send notification (optional - uncomment if you have a notification service)
        # curl -X POST "https://your-notification-service/notify" \
        #     -d "Oracle ARM instance created! IP: $PUBLIC_IP"
        
        return 0
    fi
}

# Main loop
log "Starting ARM instance retry script..."

if check_existing_arm; then
    exit 0
fi

for i in $(seq 1 $MAX_RETRIES); do
    log "Attempt $i of $MAX_RETRIES"
    
    if create_arm_instance; then
        exit 0
    fi
    
    if [ "$ONCE_MODE" = true ]; then
        log "Once mode - exiting after single attempt"
        exit 1
    fi
    
    if [ $i -lt $MAX_RETRIES ]; then
        log "Waiting ${RETRY_INTERVAL} seconds before next attempt..."
        sleep $RETRY_INTERVAL
    fi
done

log "Max retries reached. ARM capacity still unavailable."
exit 1
