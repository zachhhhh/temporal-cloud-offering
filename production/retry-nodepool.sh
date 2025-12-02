#!/bin/bash
# Retry OKE Node Pool Creation
# OCI has capacity issues, this script retries until successful

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_RETRIES=50
RETRY_DELAY=60

echo "=========================================="
echo "  OKE Node Pool Retry Script"
echo "=========================================="
echo ""
echo "OCI has capacity issues. Retrying node pool creation..."
echo "Max retries: $MAX_RETRIES"
echo "Retry delay: ${RETRY_DELAY}s"
echo ""

cd "$SCRIPT_DIR/terraform-oke"

for i in $(seq 1 $MAX_RETRIES); do
    echo "Attempt $i of $MAX_RETRIES..."
    
    if terraform apply -auto-approve 2>&1 | tee /tmp/nodepool-attempt-$i.log; then
        if grep -q "Apply complete" /tmp/nodepool-attempt-$i.log; then
            echo ""
            echo "=========================================="
            echo "  SUCCESS! Node pool created!"
            echo "=========================================="
            
            # Get kubeconfig
            CLUSTER_ID=$(terraform output -raw cluster_id)
            echo ""
            echo "Getting kubeconfig..."
            oci ce cluster create-kubeconfig \
                --cluster-id "$CLUSTER_ID" \
                --file ~/.kube/config-oke \
                --region ap-singapore-1 \
                --token-version 2.0.0 \
                --kube-endpoint PUBLIC_ENDPOINT
            
            echo ""
            echo "Kubeconfig saved to ~/.kube/config-oke"
            echo ""
            echo "To use: export KUBECONFIG=~/.kube/config-oke"
            echo ""
            exit 0
        fi
    fi
    
    if grep -q "Out of host capacity" /tmp/nodepool-attempt-$i.log; then
        echo "Capacity issue detected. Waiting ${RETRY_DELAY}s before retry..."
        sleep $RETRY_DELAY
    else
        echo "Unknown error. Check /tmp/nodepool-attempt-$i.log"
        exit 1
    fi
done

echo "Max retries reached. Please try again later or contact OCI support."
exit 1
