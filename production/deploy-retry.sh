#!/bin/bash
# Temporal Cloud - OCI Deployment with Automatic Retry
# Handles "Out of host capacity" errors by retrying until successful

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/terraform-oci"

LOG_FILE="$SCRIPT_DIR/deploy-retry.log"
MAX_RETRIES=1000  # Keep trying indefinitely
RETRY_INTERVAL=300  # 5 minutes between retries

echo "=============================================="
echo "  Temporal Cloud - OCI Retry Deployment"
echo "=============================================="
echo ""
echo "This script will keep retrying terraform apply"
echo "until the cluster is successfully deployed."
echo ""
echo "Log file: $LOG_FILE"
echo "Retry interval: ${RETRY_INTERVAL}s (5 minutes)"
echo ""
echo "Press Ctrl+C to stop at any time."
echo ""

# Initialize terraform if needed
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
fi

# Create plan
echo "Creating Terraform plan..."
terraform plan -out=.tfplan

attempt=1
while [ $attempt -le $MAX_RETRIES ]; do
    echo ""
    echo "=============================================="
    echo "  Attempt $attempt - $(date)"
    echo "=============================================="
    
    # Try to apply
    if terraform apply -auto-approve .tfplan 2>&1 | tee -a "$LOG_FILE"; then
        echo ""
        echo "=============================================="
        echo "  SUCCESS! Cluster deployed on attempt $attempt"
        echo "=============================================="
        
        # Get outputs
        SERVER_IP=$(terraform output -raw k3s_servers_ips 2>/dev/null | tr -d '[]"' | cut -d',' -f1)
        LB_IP=$(terraform output -raw public_lb_ip 2>/dev/null)
        
        echo ""
        echo "Server IP: $SERVER_IP"
        echo "Load Balancer IP: $LB_IP"
        echo ""
        echo "Next steps:"
        echo "  1. Run: ./deploy-oci.sh temporal"
        echo "  2. Configure DNS to point to $LB_IP"
        echo ""
        
        # Send notification (optional - uncomment if you have ntfy.sh)
        # curl -d "Temporal Cloud deployed! LB: $LB_IP" ntfy.sh/your-topic
        
        exit 0
    fi
    
    # Check if it's a capacity error
    if grep -q "Out of host capacity" "$LOG_FILE" 2>/dev/null; then
        echo ""
        echo "⚠️  Out of host capacity - ARM instances unavailable"
        echo "   Waiting ${RETRY_INTERVAL}s before retry..."
        echo "   (Attempt $attempt failed at $(date))"
        echo ""
        
        # Recreate plan for next attempt
        terraform plan -out=.tfplan 2>&1 | tee -a "$LOG_FILE"
        
        sleep $RETRY_INTERVAL
        ((attempt++))
    else
        echo ""
        echo "❌ Deployment failed with unexpected error"
        echo "   Check $LOG_FILE for details"
        exit 1
    fi
done

echo "Max retries ($MAX_RETRIES) reached. Giving up."
exit 1
