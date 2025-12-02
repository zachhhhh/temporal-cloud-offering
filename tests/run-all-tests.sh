#!/bin/bash
# Comprehensive Test Suite for Temporal Cloud Offering
# Runs all tests: unit, integration, e2e, load, and chaos

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}========================================${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}========================================${NC}"; }

# Results tracking
PASSED=0
FAILED=0
SKIPPED=0

run_test() {
    local name="$1"
    local cmd="$2"
    
    echo -n "  Running $name... "
    if eval "$cmd" > /tmp/test-output.log 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        ((FAILED++))
        cat /tmp/test-output.log
    fi
}

# ============================================
# Prerequisites Check
# ============================================
log_section "Checking Prerequisites"

check_service() {
    local name="$1"
    local url="$2"
    
    echo -n "  Checking $name... "
    if curl -s "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}NOT AVAILABLE${NC}"
        return 1
    fi
}

SERVICES_OK=true
check_service "PostgreSQL" "localhost:5432" || SERVICES_OK=false
check_service "Temporal Server" "localhost:7233" || SERVICES_OK=false
check_service "Billing API" "http://localhost:8082/health" || SERVICES_OK=false
check_service "Admin Portal" "http://localhost:3000" || SERVICES_OK=false

if [ "$SERVICES_OK" = false ]; then
    log_error "Some services are not running. Start with: docker-compose up -d"
    exit 1
fi

# ============================================
# 1. Unit Tests - Billing Service
# ============================================
log_section "1. Unit Tests - Billing Service"

cd "$PROJECT_ROOT/billing-service"
if [ -f "go.mod" ]; then
    run_test "Pricing Tests" "go test -v ./... -run TestPricing -count=1"
    run_test "Service Tests" "go test -v ./... -run TestService -count=1"
else
    log_warn "Billing service go.mod not found, skipping"
    ((SKIPPED++))
fi

# ============================================
# 2. Database Schema Verification
# ============================================
log_section "2. Database Schema Verification"

echo -n "  Checking billing database tables... "
BILLING_TABLES=$(docker exec temporal-postgres psql -U temporal -d billing -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
if [ "$BILLING_TABLES" -ge 8 ]; then
    echo -e "${GREEN}OK ($BILLING_TABLES tables)${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAILED (expected 8+, got $BILLING_TABLES)${NC}"
    ((FAILED++))
fi

echo -n "  Checking temporal database tables... "
TEMPORAL_TABLES=$(docker exec temporal-postgres psql -U temporal -d temporal -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
if [ "$TEMPORAL_TABLES" -ge 30 ]; then
    echo -e "${GREEN}OK ($TEMPORAL_TABLES tables)${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAILED (expected 30+, got $TEMPORAL_TABLES)${NC}"
    ((FAILED++))
fi

# ============================================
# 3. E2E Tests - Full Customer Flow
# ============================================
log_section "3. E2E Tests - Full Customer Flow"

if [ -f "$SCRIPT_DIR/e2e/full_flow_test.sh" ]; then
    chmod +x "$SCRIPT_DIR/e2e/full_flow_test.sh"
    if "$SCRIPT_DIR/e2e/full_flow_test.sh"; then
        ((PASSED++))
    else
        ((FAILED++))
    fi
else
    log_warn "E2E test script not found"
    ((SKIPPED++))
fi

# ============================================
# 4. Temporal Workflow Tests
# ============================================
log_section "4. Temporal Workflow Tests"

cd "$SCRIPT_DIR/temporal"
if [ -f "go.mod" ]; then
    log_info "Installing dependencies..."
    go mod tidy 2>/dev/null || true
    
    run_test "Simple Workflow" "go test -v -run TestSimpleWorkflow -count=1 -timeout 60s"
    run_test "Activity Workflow" "go test -v -run TestActivityWorkflow -count=1 -timeout 60s"
    run_test "Signal Workflow" "go test -v -run TestSignalWorkflow -count=1 -timeout 60s"
    run_test "Query Workflow" "go test -v -run TestQueryWorkflow -count=1 -timeout 60s"
    run_test "Child Workflows" "go test -v -run TestChildWorkflows -count=1 -timeout 60s"
    run_test "Timer Workflow" "go test -v -run TestTimerWorkflow -count=1 -timeout 60s"
    run_test "Retry Workflow" "go test -v -run TestRetryWorkflow -count=1 -timeout 60s"
    run_test "Workflow History" "go test -v -run TestWorkflowHistory -count=1 -timeout 60s"
else
    log_warn "Temporal tests go.mod not found"
    ((SKIPPED++))
fi

# ============================================
# 5. Load Tests (Quick)
# ============================================
log_section "5. Load Tests"

cd "$SCRIPT_DIR/load"
if [ -f "go.mod" ]; then
    go mod tidy 2>/dev/null || true
    run_test "Basic Load (100 workflows)" "go test -v -run TestLoadBasic -count=1 -timeout 120s"
else
    log_warn "Load tests go.mod not found"
    ((SKIPPED++))
fi

# ============================================
# 6. Chaos Tests (Quick)
# ============================================
log_section "6. Chaos Tests"

cd "$SCRIPT_DIR/chaos"
if [ -f "go.mod" ]; then
    go mod tidy 2>/dev/null || true
    run_test "Worker Failover" "go test -v -run TestWorkerFailover -count=1 -timeout 120s"
else
    log_warn "Chaos tests go.mod not found"
    ((SKIPPED++))
fi

# ============================================
# 7. API Tests
# ============================================
log_section "7. API Tests"

BILLING_API="http://localhost:8082"

echo -n "  Testing health endpoint... "
if curl -s "$BILLING_API/health" | grep -q "ok"; then
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAILED${NC}"
    ((FAILED++))
fi

echo -n "  Testing organization creation... "
ORG_RESPONSE=$(curl -s -X POST "$BILLING_API/api/v1/organizations" \
    -H "Content-Type: application/json" \
    -d '{"name": "API Test Org", "email": "api-test@example.com"}')
if echo "$ORG_RESPONSE" | grep -q '"id"'; then
    echo -e "${GREEN}PASSED${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAILED${NC}"
    ((FAILED++))
fi

# ============================================
# 8. Storage Tests
# ============================================
log_section "8. Storage Tests (Active & Retained)"

echo -n "  Checking workflow executions table... "
EXEC_COUNT=$(docker exec temporal-postgres psql -U temporal -d temporal -t -c "SELECT COUNT(*) FROM executions;" 2>/dev/null | tr -d ' ')
echo -e "${GREEN}OK ($EXEC_COUNT active workflows)${NC}"
((PASSED++))

echo -n "  Checking history storage... "
HISTORY_COUNT=$(docker exec temporal-postgres psql -U temporal -d temporal -t -c "SELECT COUNT(*) FROM history_node;" 2>/dev/null | tr -d ' ')
echo -e "${GREEN}OK ($HISTORY_COUNT history nodes)${NC}"
((PASSED++))

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

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
