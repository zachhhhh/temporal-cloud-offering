#!/bin/bash
# Temporal Cloud - Test Runner
# Usage: ./run-tests.sh [unit|e2e|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

run_unit_tests() {
    log_info "Running unit tests..."
    
    # Billing service tests
    log_info "Testing billing-service..."
    cd "$PROJECT_ROOT/billing-service"
    go test -v ./... -coverprofile=coverage.out
    go tool cover -func=coverage.out | tail -1
    
    # Usage collector tests (if any)
    if [ -f "$PROJECT_ROOT/usage-collector/main_test.go" ]; then
        log_info "Testing usage-collector..."
        cd "$PROJECT_ROOT/usage-collector"
        go test -v ./...
    fi
    
    log_info "Unit tests completed!"
}

run_e2e_tests() {
    log_info "Running E2E tests..."
    
    # Check if services are running
    if ! curl -s http://localhost:8082/health > /dev/null 2>&1; then
        log_warn "Billing service not running. Starting docker-compose..."
        cd "$PROJECT_ROOT/deploy"
        docker-compose up -d postgres billing-service
        sleep 5
    fi
    
    # Run E2E tests
    cd "$SCRIPT_DIR/e2e"
    BILLING_API=${BILLING_API:-http://localhost:8082} \
    TEST_ORG_ID=${TEST_ORG_ID:-demo-org} \
    go test -v -tags=e2e ./...
    
    log_info "E2E tests completed!"
}

run_integration_tests() {
    log_info "Running integration tests with database..."
    
    # Start test database if not running
    if ! docker ps | grep -q temporal-test-db; then
        log_info "Starting test database..."
        docker run -d --name temporal-test-db \
            -e POSTGRES_USER=temporal \
            -e POSTGRES_PASSWORD=temporal123 \
            -e POSTGRES_DB=billing_test \
            -p 5433:5432 \
            postgres:15-alpine
        sleep 3
        
        # Initialize schema
        docker exec -i temporal-test-db psql -U temporal -d billing_test < "$PROJECT_ROOT/deploy/init-db.sql"
    fi
    
    # Run tests with database
    cd "$PROJECT_ROOT/billing-service"
    TEST_DATABASE_URL="postgres://temporal:temporal123@localhost:5433/billing_test?sslmode=disable" \
    go test -v ./...
    
    log_info "Integration tests completed!"
}

cleanup() {
    log_info "Cleaning up test resources..."
    docker rm -f temporal-test-db 2>/dev/null || true
}

print_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  unit        Run unit tests only"
    echo "  e2e         Run E2E tests (requires running services)"
    echo "  integration Run integration tests with database"
    echo "  all         Run all tests"
    echo "  cleanup     Remove test containers"
    echo ""
}

case "${1:-all}" in
    unit)
        run_unit_tests
        ;;
    e2e)
        run_e2e_tests
        ;;
    integration)
        run_integration_tests
        ;;
    all)
        run_unit_tests
        run_integration_tests
        ;;
    cleanup)
        cleanup
        ;;
    *)
        print_usage
        exit 1
        ;;
esac

log_info "All tests passed!"
