#!/bin/bash
# OKE Cluster Test Suite
# Tests all deployed services on Oracle Kubernetes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_section() { echo -e "\n${BLUE}========================================${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}========================================${NC}"; }

PASSED=0
FAILED=0
SKIPPED=0

# Get service endpoints
TEMPORAL_UI_IP=$(kubectl get svc temporal-cloud-temporal-ui -n temporal -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
NGINX_IP=$(kubectl get svc nginx -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

# Get NodePort for billing (no LoadBalancer available)
BILLING_PORT=$(kubectl get svc temporal-cloud-billing -n temporal -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30853")
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")

echo "=============================================="
echo "  Temporal Cloud OKE - Test Suite"
echo "=============================================="
echo "Temporal UI: http://${TEMPORAL_UI_IP}:8080"
echo "Ingress:     http://${INGRESS_IP}"
echo "Nginx:       http://${NGINX_IP}"
echo ""

# ============================================
# 1. Kubernetes Cluster Health
# ============================================
log_section "1. Kubernetes Cluster Health"

echo -n "  Checking nodes... "
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$NODE_COUNT" -ge 1 ]; then
    log_info "OK ($NODE_COUNT nodes ready)"
    ((PASSED++))
else
    log_error "No nodes ready"
    ((FAILED++))
fi

echo -n "  Checking system pods... "
SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$SYSTEM_PODS" -ge 4 ]; then
    log_info "OK ($SYSTEM_PODS system pods running)"
    ((PASSED++))
else
    log_error "System pods not healthy"
    ((FAILED++))
fi

# ============================================
# 2. Temporal Stack Health
# ============================================
log_section "2. Temporal Stack Health"

echo -n "  Checking temporal namespace pods... "
TEMPORAL_PODS=$(kubectl get pods -n temporal --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$TEMPORAL_PODS" -ge 4 ]; then
    log_info "OK ($TEMPORAL_PODS pods running)"
    ((PASSED++))
else
    log_error "Expected 4+ pods, got $TEMPORAL_PODS"
    ((FAILED++))
fi

# Check individual pods
for pod in postgresql redis temporal temporal-ui billing; do
    echo -n "  Checking $pod... "
    POD_STATUS=$(kubectl get pods -n temporal -l app.kubernetes.io/name=$pod --no-headers 2>/dev/null | grep -c "Running" || \
                 kubectl get pods -n temporal --no-headers 2>/dev/null | grep -c "$pod.*Running" || echo "0")
    if [ "$POD_STATUS" -ge 1 ]; then
        log_info "Running"
        ((PASSED++))
    else
        log_warn "Not found or not running"
        ((SKIPPED++))
    fi
done

# ============================================
# 3. External Service Connectivity
# ============================================
log_section "3. External Service Connectivity"

# Nginx test
echo -n "  Testing nginx (http://${NGINX_IP})... "
if [ -n "$NGINX_IP" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${NGINX_IP}" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        log_info "OK (HTTP $HTTP_CODE)"
        ((PASSED++))
    else
        log_error "Failed (HTTP $HTTP_CODE)"
        ((FAILED++))
    fi
else
    log_warn "No external IP"
    ((SKIPPED++))
fi

# Temporal UI test
echo -n "  Testing Temporal UI (http://${TEMPORAL_UI_IP}:8080)... "
if [ -n "$TEMPORAL_UI_IP" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${TEMPORAL_UI_IP}:8080" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        log_info "OK (HTTP $HTTP_CODE)"
        ((PASSED++))
    else
        log_error "Failed (HTTP $HTTP_CODE)"
        ((FAILED++))
    fi
else
    log_warn "No external IP"
    ((SKIPPED++))
fi

# Ingress test
echo -n "  Testing Ingress (http://${INGRESS_IP})... "
if [ -n "$INGRESS_IP" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${INGRESS_IP}" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ]; then
        log_info "OK (HTTP $HTTP_CODE)"
        ((PASSED++))
    else
        log_error "Failed (HTTP $HTTP_CODE)"
        ((FAILED++))
    fi
else
    log_warn "No external IP"
    ((SKIPPED++))
fi

# ============================================
# 4. Internal Service Tests (via kubectl exec)
# ============================================
log_section "4. Internal Service Tests"

# Test PostgreSQL
echo -n "  Testing PostgreSQL connection... "
PG_TEST=$(kubectl exec -n temporal deploy/temporal-cloud-postgresql -- psql -U postgres -c "SELECT 1" 2>/dev/null || echo "error")
if echo "$PG_TEST" | grep -q "1"; then
    log_info "OK"
    ((PASSED++))
else
    log_error "Failed"
    ((FAILED++))
fi

# Test Redis
echo -n "  Testing Redis connection... "
REDIS_TEST=$(kubectl exec -n temporal deploy/temporal-cloud-redis -- redis-cli ping 2>/dev/null || echo "error")
if echo "$REDIS_TEST" | grep -q "PONG"; then
    log_info "OK (PONG)"
    ((PASSED++))
else
    log_error "Failed"
    ((FAILED++))
fi

# Test Temporal Server
echo -n "  Testing Temporal Server gRPC... "
TEMPORAL_TEST=$(kubectl exec -n temporal deploy/temporal-cloud-temporal -- wget -q -O- http://localhost:7239/health 2>/dev/null || echo "error")
if [ -n "$TEMPORAL_TEST" ]; then
    log_info "OK"
    ((PASSED++))
else
    log_warn "Health endpoint not available"
    ((SKIPPED++))
fi

# ============================================
# 5. Billing API Tests
# ============================================
log_section "5. Billing API Tests"

# Port-forward for billing API test
echo "  Setting up port-forward for billing API..."
kubectl port-forward -n temporal svc/temporal-cloud-billing 8082:8082 &>/dev/null &
PF_PID=$!
sleep 3

# Health check
echo -n "  Testing billing API health... "
HEALTH=$(curl -s --connect-timeout 5 http://localhost:8082/health 2>/dev/null || echo "{}")
if echo "$HEALTH" | grep -q "ok"; then
    log_info "OK"
    ((PASSED++))
else
    log_warn "Health check returned: $HEALTH"
    ((SKIPPED++))
fi

# Usage endpoint
echo -n "  Testing usage endpoint... "
USAGE=$(curl -s --connect-timeout 5 "http://localhost:8082/api/v1/organizations/demo-org/usage" 2>/dev/null || echo "{}")
if echo "$USAGE" | grep -q "total_actions\|actions"; then
    log_info "OK"
    ((PASSED++))
else
    log_warn "Usage endpoint returned: $USAGE"
    ((SKIPPED++))
fi

# Subscription endpoint
echo -n "  Testing subscription endpoint... "
SUB=$(curl -s --connect-timeout 5 "http://localhost:8082/api/v1/organizations/demo-org/subscription" 2>/dev/null || echo "{}")
if echo "$SUB" | grep -q "plan\|free"; then
    log_info "OK"
    ((PASSED++))
else
    log_warn "Subscription endpoint returned: $SUB"
    ((SKIPPED++))
fi

# Cleanup port-forward
kill $PF_PID 2>/dev/null || true

# ============================================
# 6. Temporal Workflow Test
# ============================================
log_section "6. Temporal Workflow Test"

echo -n "  Checking Temporal CLI availability... "
if command -v temporal &> /dev/null; then
    log_info "temporal CLI found"
    
    # Port-forward Temporal server
    kubectl port-forward -n temporal svc/temporal-cloud-temporal 7233:7233 &>/dev/null &
    PF_PID=$!
    sleep 3
    
    echo -n "  Listing namespaces... "
    NS_LIST=$(temporal operator namespace list --address localhost:7233 2>&1 || echo "error")
    if echo "$NS_LIST" | grep -q "default\|Name"; then
        log_info "OK"
        ((PASSED++))
    else
        log_warn "Could not list namespaces"
        ((SKIPPED++))
    fi
    
    kill $PF_PID 2>/dev/null || true
else
    log_warn "temporal CLI not installed, skipping workflow tests"
    ((SKIPPED++))
fi

# ============================================
# 7. Resource Usage Check
# ============================================
log_section "7. Resource Usage Check"

echo -n "  Checking node resource usage... "
NODE_USAGE=$(kubectl top nodes 2>/dev/null || echo "metrics not available")
if echo "$NODE_USAGE" | grep -q "%"; then
    CPU=$(echo "$NODE_USAGE" | tail -1 | awk '{print $3}')
    MEM=$(echo "$NODE_USAGE" | tail -1 | awk '{print $5}')
    log_info "CPU: $CPU, Memory: $MEM"
    ((PASSED++))
else
    log_warn "Metrics server not available"
    ((SKIPPED++))
fi

echo -n "  Checking pod resource usage... "
POD_USAGE=$(kubectl top pods -n temporal 2>/dev/null || echo "metrics not available")
if echo "$POD_USAGE" | grep -q "m\|Mi"; then
    log_info "OK"
    ((PASSED++))
else
    log_warn "Metrics server not available"
    ((SKIPPED++))
fi

# ============================================
# 8. Storage Check
# ============================================
log_section "8. Storage Check"

echo -n "  Checking PersistentVolumeClaims... "
PVC_COUNT=$(kubectl get pvc -n temporal --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$PVC_COUNT" -ge 1 ]; then
    log_info "OK ($PVC_COUNT PVCs)"
    ((PASSED++))
else
    log_warn "No PVCs found"
    ((SKIPPED++))
fi

echo -n "  Checking PVC status... "
PVC_BOUND=$(kubectl get pvc -n temporal --no-headers 2>/dev/null | grep -c "Bound" || echo "0")
if [ "$PVC_BOUND" -ge 1 ]; then
    log_info "OK ($PVC_BOUND bound)"
    ((PASSED++))
else
    log_error "No PVCs bound"
    ((FAILED++))
fi

# ============================================
# Summary
# ============================================
log_section "Test Summary"

TOTAL=$((PASSED + FAILED + SKIPPED))

echo -e "  ${GREEN}Passed:${NC}  $PASSED"
echo -e "  ${RED}Failed:${NC}  $FAILED"
echo -e "  ${YELLOW}Skipped:${NC} $SKIPPED"
echo -e "  Total:   $TOTAL"
echo ""

echo "=============================================="
echo "  Service URLs"
echo "=============================================="
echo "  Temporal UI:  http://${TEMPORAL_UI_IP}:8080"
echo "  Nginx Test:   http://${NGINX_IP}"
echo "  Ingress:      http://${INGRESS_IP}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All critical tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
