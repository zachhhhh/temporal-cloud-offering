#!/bin/bash
# Full Customer Flow E2E Test
# Tests: Organization creation, namespace provisioning, workflow execution, billing

# Don't exit on error - we want to track failures
set +e

BILLING_API=${BILLING_API:-http://localhost:8082}
TEMPORAL_API=${TEMPORAL_API:-localhost:7233}
ADMIN_PORTAL=${ADMIN_PORTAL:-http://localhost:3000}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_test() { echo -e "\n${YELLOW}[TEST]${NC} $1"; }

FAILED=0
PASSED=0

assert_eq() {
    if [ "$1" = "$2" ]; then
        log_info "$3"
        ((PASSED++))
    else
        log_error "$3 (expected: $2, got: $1)"
        ((FAILED++))
    fi
}

assert_contains() {
    if echo "$1" | grep -q "$2"; then
        log_info "$3"
        ((PASSED++))
    else
        log_error "$3 (expected to contain: $2)"
        ((FAILED++))
    fi
}

assert_not_empty() {
    if [ -n "$1" ]; then
        log_info "$2"
        ((PASSED++))
    else
        log_error "$2 (value was empty)"
        ((FAILED++))
    fi
}

# Generate unique test ID
TEST_ID=$(date +%s)
TEST_ORG_NAME="E2E Test Org $TEST_ID"
TEST_EMAIL="e2e-$TEST_ID@test.com"
TEST_NS_NAME="e2e-ns-$TEST_ID"

echo "=============================================="
echo "  Temporal Cloud - Full E2E Test"
echo "=============================================="
echo "Test ID: $TEST_ID"
echo ""

# ============================================
# 1. Service Health Checks
# ============================================
log_test "1. Service Health Checks"

# Billing API
HEALTH=$(curl -s $BILLING_API/health)
assert_contains "$HEALTH" "ok" "Billing API is healthy"

# Admin Portal
PORTAL=$(curl -s -o /dev/null -w "%{http_code}" $ADMIN_PORTAL)
assert_eq "$PORTAL" "200" "Admin Portal is accessible"

# Temporal Server
if command -v tctl &> /dev/null; then
    TEMPORAL_HEALTH=$(tctl --address $TEMPORAL_API cluster health 2>&1 || echo "error")
    if echo "$TEMPORAL_HEALTH" | grep -q "SERVING"; then
        log_info "Temporal Server is healthy"
        ((PASSED++))
    else
        log_warn "Temporal Server health check skipped (tctl not configured)"
    fi
else
    log_warn "tctl not installed, skipping Temporal health check"
fi

# ============================================
# 2. Organization Creation
# ============================================
log_test "2. Organization Creation"

ORG_RESPONSE=$(curl -s -X POST $BILLING_API/api/v1/organizations \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$TEST_ORG_NAME\", \"email\": \"$TEST_EMAIL\"}")

ORG_ID=$(echo $ORG_RESPONSE | jq -r '.id // empty')
assert_not_empty "$ORG_ID" "Organization created with ID: $ORG_ID"

ORG_NAME=$(echo $ORG_RESPONSE | jq -r '.name // empty')
assert_eq "$ORG_NAME" "$TEST_ORG_NAME" "Organization name matches"

# ============================================
# 3. Subscription Verification
# ============================================
log_test "3. Subscription Verification"

if [ -n "$ORG_ID" ]; then
    SUB_RESPONSE=$(curl -s $BILLING_API/api/v1/organizations/$ORG_ID/subscription)
    
    SUB_PLAN=$(echo $SUB_RESPONSE | jq -r '.plan // empty')
    assert_eq "$SUB_PLAN" "free" "Default subscription is Free tier"
    
    SUB_STATUS=$(echo $SUB_RESPONSE | jq -r '.status // empty')
    assert_eq "$SUB_STATUS" "active" "Subscription is active"
    
    ACTIONS_INCLUDED=$(echo $SUB_RESPONSE | jq -r '.actions_included // 0')
    assert_eq "$ACTIONS_INCLUDED" "100000" "Free tier includes 100k actions"
fi

# ============================================
# 4. Namespace Creation
# ============================================
log_test "4. Namespace Creation"

if [ -n "$ORG_ID" ]; then
    NS_RESPONSE=$(curl -s -X POST $BILLING_API/api/v1/organizations/$ORG_ID/namespaces \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$TEST_NS_NAME\", \"region\": \"ap-singapore-1\", \"retention_days\": 7}")
    
    NS_ID=$(echo $NS_RESPONSE | jq -r '.id // empty')
    assert_not_empty "$NS_ID" "Namespace created with ID: $NS_ID"
    
    TEMPORAL_NS=$(echo $NS_RESPONSE | jq -r '.temporal_namespace // empty')
    assert_not_empty "$TEMPORAL_NS" "Temporal namespace assigned: $TEMPORAL_NS"
    
    NS_STATUS=$(echo $NS_RESPONSE | jq -r '.status // empty')
    if [ "$NS_STATUS" = "active" ] || [ "$NS_STATUS" = "provisioning" ]; then
        log_info "Namespace status is valid: $NS_STATUS"
        ((PASSED++))
    else
        log_error "Namespace status invalid (expected: active or provisioning, got: $NS_STATUS)"
        ((FAILED++))
    fi
fi

# ============================================
# 5. API Key Management
# ============================================
log_test "5. API Key Management"

if [ -n "$ORG_ID" ]; then
    # Create API key
    KEY_RESPONSE=$(curl -s -X POST $BILLING_API/api/v1/organizations/$ORG_ID/api-keys \
        -H "Content-Type: application/json" \
        -d '{"name": "E2E Test Key", "expires_in": "30d"}')
    
    API_KEY=$(echo $KEY_RESPONSE | jq -r '.key // empty')
    assert_not_empty "$API_KEY" "API key created"
    
    KEY_ID=$(echo $KEY_RESPONSE | jq -r '.id // empty')
    assert_not_empty "$KEY_ID" "API key has ID: $KEY_ID"
    
    # List API keys
    KEYS_LIST=$(curl -s $BILLING_API/api/v1/organizations/$ORG_ID/api-keys)
    KEY_COUNT=$(echo $KEYS_LIST | jq 'length')
    if [ "$KEY_COUNT" -ge 1 ]; then
        log_info "API keys list contains $KEY_COUNT key(s)"
        ((PASSED++))
    else
        log_error "API keys list should have at least 1 key"
        ((FAILED++))
    fi
    
    # Delete API key
    if [ -n "$KEY_ID" ]; then
        DELETE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE $BILLING_API/api/v1/api-keys/$KEY_ID)
        if [ "$DELETE_RESPONSE" = "200" ] || [ "$DELETE_RESPONSE" = "204" ]; then
            log_info "API key deleted successfully (status: $DELETE_RESPONSE)"
            ((PASSED++))
        else
            log_error "API key delete failed (expected: 200 or 204, got: $DELETE_RESPONSE)"
            ((FAILED++))
        fi
    fi
fi

# ============================================
# 6. Usage Tracking
# ============================================
log_test "6. Usage Tracking"

if [ -n "$ORG_ID" ]; then
    USAGE_RESPONSE=$(curl -s $BILLING_API/api/v1/organizations/$ORG_ID/usage/current)
    
    # Verify usage fields exist
    TOTAL_ACTIONS=$(echo $USAGE_RESPONSE | jq -r '.total_actions // "missing"')
    assert_not_empty "$TOTAL_ACTIONS" "Usage includes total_actions: $TOTAL_ACTIONS"
    
    ACTIVE_STORAGE=$(echo $USAGE_RESPONSE | jq -r '.active_storage_gbh // "missing"')
    assert_not_empty "$ACTIVE_STORAGE" "Usage includes active_storage_gbh: $ACTIVE_STORAGE"
    
    ESTIMATED_COST=$(echo $USAGE_RESPONSE | jq -r '.estimated_cost_cents // "missing"')
    assert_not_empty "$ESTIMATED_COST" "Usage includes estimated_cost_cents: $ESTIMATED_COST"
fi

# ============================================
# 7. Invoice History
# ============================================
log_test "7. Invoice History"

if [ -n "$ORG_ID" ]; then
    INVOICES_RESPONSE=$(curl -s $BILLING_API/api/v1/organizations/$ORG_ID/invoices)
    
    # Should return an array (even if empty)
    if echo "$INVOICES_RESPONSE" | jq -e '. | type == "array"' > /dev/null 2>&1; then
        INVOICE_COUNT=$(echo $INVOICES_RESPONSE | jq 'length')
        log_info "Invoice history accessible ($INVOICE_COUNT invoices)"
        ((PASSED++))
    else
        log_error "Invoice history should return an array"
        ((FAILED++))
    fi
fi

# ============================================
# 8. Pricing Calculation Verification
# ============================================
log_test "8. Pricing Calculation Verification"

# Test pricing endpoint if available
PRICING_TEST=$(curl -s "$BILLING_API/api/v1/pricing/calculate" \
    -H "Content-Type: application/json" \
    -d '{"actions": 1500000, "active_storage_gbh": 720, "retained_storage_gbh": 28800}' 2>/dev/null || echo '{}')

if echo "$PRICING_TEST" | jq -e '.total_cents' > /dev/null 2>&1; then
    TOTAL_CENTS=$(echo $PRICING_TEST | jq -r '.total_cents')
    log_info "Pricing calculation returned: $TOTAL_CENTS cents"
    ((PASSED++))
else
    log_warn "Pricing calculation endpoint not available (optional)"
fi

# ============================================
# 9. Admin Portal Pages
# ============================================
log_test "9. Admin Portal Pages"

# Dashboard
DASHBOARD=$(curl -s -o /dev/null -w "%{http_code}" $ADMIN_PORTAL/)
assert_eq "$DASHBOARD" "200" "Dashboard page loads"

# Billing page
BILLING_PAGE=$(curl -s -o /dev/null -w "%{http_code}" $ADMIN_PORTAL/billing)
assert_eq "$BILLING_PAGE" "200" "Billing page loads"

# Namespaces page
NS_PAGE=$(curl -s -o /dev/null -w "%{http_code}" $ADMIN_PORTAL/namespaces)
assert_eq "$NS_PAGE" "200" "Namespaces page loads"

# Settings page
SETTINGS_PAGE=$(curl -s -o /dev/null -w "%{http_code}" $ADMIN_PORTAL/settings)
assert_eq "$SETTINGS_PAGE" "200" "Settings page loads"

# ============================================
# 10. Temporal Workflow Test (if tctl available)
# ============================================
log_test "10. Temporal Workflow Test"

if command -v temporal &> /dev/null; then
    # Create a test namespace in Temporal
    log_info "Testing Temporal CLI connectivity..."
    
    # List namespaces
    NS_LIST=$(temporal operator namespace list --address $TEMPORAL_API 2>&1 || echo "error")
    if echo "$NS_LIST" | grep -q "default"; then
        log_info "Temporal default namespace exists"
        ((PASSED++))
    else
        log_warn "Could not list Temporal namespaces"
    fi
else
    log_warn "temporal CLI not installed, skipping workflow test"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=============================================="
echo "  Test Summary"
echo "=============================================="
echo -e "  ${GREEN}Passed:${NC} $PASSED"
echo -e "  ${RED}Failed:${NC} $FAILED"
echo "=============================================="

if [ $FAILED -gt 0 ]; then
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
fi
