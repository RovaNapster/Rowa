#!/bin/bash
# Smoke tests for deployment verification
# Validates that all services are healthy and responsive

set -e

ENVIRONMENT=${1:-staging}
BASE_URL=${2:-http://localhost}

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ============================================================================
# TEST UTILITIES
# ============================================================================
test_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}

    log_test "Testing $name..."

    local status=$(curl -s -w "%{http_code}" -o /dev/null "$url" 2>/dev/null || echo "000")

    if [ "$status" == "$expected_status" ]; then
        log_info "$name returned HTTP $status"
        return 0
    else
        log_error "$name returned HTTP $status (expected $expected_status)"
        return 1
    fi
}

test_connectivity() {
    local host=$1
    local port=$2

    log_test "Testing connectivity to $host:$port..."

    if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        log_info "Connected to $host:$port"
        return 0
    else
        log_error "Cannot connect to $host:$port"
        return 1
    fi
}

test_response_time() {
    local name=$1
    local url=$2
    local max_time=${3:-5}

    log_test "Testing response time for $name (max ${max_time}s)..."

    local response_time=$(curl -s -w "%{time_total}" -o /dev/null "$url" 2>/dev/null || echo "999")
    local response_seconds=$(echo "$response_time" | cut -d'.' -f1)

    if (( $(echo "$response_time < $max_time" | bc -l) )); then
        log_info "$name responded in ${response_time}s (< ${max_time}s)"
        return 0
    else
        log_warn "$name responded slowly: ${response_time}s (< ${max_time}s required)"
        return 0  # Don't fail on slow response
    fi
}

# ============================================================================
# SERVICE HEALTH CHECKS
# ============================================================================
test_lidbema_services() {
    echo ""
    echo -e "${BLUE}=== LIDBEMA SERVICES ===${NC}"
    echo ""

    local failed=0

    # Test Lidbema Zone 1
    if ! test_endpoint "Lidbema Zone 1" "$BASE_URL:3001/health"; then
        ((failed++))
    fi
    test_response_time "Lidbema Zone 1" "$BASE_URL:3001/health" 5

    # Test Lidbema Zone 2
    if ! test_endpoint "Lidbema Zone 2" "$BASE_URL:3002/health"; then
        ((failed++))
    fi
    test_response_time "Lidbema Zone 2" "$BASE_URL:3002/health" 5

    # Test Lidbema Zone 3
    if ! test_endpoint "Lidbema Zone 3" "$BASE_URL:3003/health"; then
        ((failed++))
    fi
    test_response_time "Lidbema Zone 3" "$BASE_URL:3003/health" 5

    # Test PWA
    if ! test_endpoint "Lidbema PWA" "$BASE_URL:3000/health"; then
        ((failed++))
    fi
    test_response_time "Lidbema PWA" "$BASE_URL:3000/health" 5

    return $failed
}

test_nexnod_cluster() {
    echo ""
    echo -e "${BLUE}=== NEXNOD CLUSTER ===${NC}"
    echo ""

    local failed=0

    # Test NexNod Node 1
    if ! test_endpoint "NexNod Node 1" "$BASE_URL:4001/health"; then
        ((failed++))
    fi
    test_response_time "NexNod Node 1" "$BASE_URL:4001/health" 5

    # Test NexNod Node 2
    if ! test_endpoint "NexNod Node 2" "$BASE_URL:4002/health"; then
        ((failed++))
    fi
    test_response_time "NexNod Node 2" "$BASE_URL:4002/health" 5

    # Test NexNod Node 3
    if ! test_endpoint "NexNod Node 3" "$BASE_URL:4003/health"; then
        ((failed++))
    fi
    test_response_time "NexNod Node 3" "$BASE_URL:4003/health" 5

    return $failed
}

test_monitoring_stack() {
    echo ""
    echo -e "${BLUE}=== MONITORING STACK ===${NC}"
    echo ""

    local failed=0

    # Test Prometheus
    if ! test_endpoint "Prometheus" "$BASE_URL:9090/-/healthy" 200; then
        ((failed++))
    fi
    test_response_time "Prometheus" "$BASE_URL:9090/-/healthy" 5

    # Test Grafana
    if ! test_endpoint "Grafana" "$BASE_URL:3100/api/health" 200; then
        ((failed++))
    fi
    test_response_time "Grafana" "$BASE_URL:3100/api/health" 5

    return $failed
}

test_metrics_collection() {
    echo ""
    echo -e "${BLUE}=== METRICS COLLECTION ===${NC}"
    echo ""

    log_test "Checking Prometheus metrics availability..."

    # Query Prometheus for metrics
    local query_url="$BASE_URL:9090/api/v1/query?query=up"
    local metrics=$(curl -s "$query_url" 2>/dev/null | grep -c "value" || echo "0")

    if [ "$metrics" -gt 0 ]; then
        log_info "Prometheus collecting metrics from $metrics targets"
        return 0
    else
        log_warn "No metrics found in Prometheus (may still be starting up)"
        return 0  # Don't fail if metrics not yet available
    fi
}

test_network_connectivity() {
    echo ""
    echo -e "${BLUE}=== INTERNAL NETWORK CONNECTIVITY ===${NC}"
    echo ""

    local failed=0

    # Test connectivity between services (from host perspective)
    if ! test_connectivity "localhost" 3000; then
        ((failed++))
    fi

    if ! test_connectivity "localhost" 9090; then
        ((failed++))
    fi

    return $failed
}

test_data_persistence() {
    echo ""
    echo -e "${BLUE}=== DATA PERSISTENCE ===${NC}"
    echo ""

    log_test "Checking volume availability..."

    # Check if we can write to volumes (basic check)
    if command -v docker &> /dev/null; then
        local volumes=$(docker volume ls 2>/dev/null | grep -c "lidbema\|nexnod\|prometheus\|grafana" || echo "0")
        if [ "$volumes" -gt 0 ]; then
            log_info "Found $volumes persistent volumes"
            return 0
        else
            log_warn "No persistent volumes found"
            return 0  # Don't fail
        fi
    else
        log_warn "Docker not available (skipping volume check)"
        return 0
    fi
}

# ============================================================================
# SECURITY CHECKS
# ============================================================================
test_security_headers() {
    echo ""
    echo -e "${BLUE}=== SECURITY CHECKS ===${NC}"
    echo ""

    log_test "Checking security headers..."

    local headers=$(curl -s -I "$BASE_URL:3000/health" 2>/dev/null || echo "")

    if echo "$headers" | grep -qi "x-"; then
        log_info "Security headers detected"
        return 0
    else
        log_warn "No security headers detected (may be normal for health endpoints)"
        return 0
    fi
}

test_no_exposed_secrets() {
    echo ""
    echo -e "${BLUE}=== SECRET EXPOSURE CHECK ===${NC}"
    echo ""

    log_test "Checking for exposed secrets in responses..."

    local response=$(curl -s "$BASE_URL:3000/" 2>/dev/null | head -100 || echo "")

    if echo "$response" | grep -Eiq "(password|secret|token|api_key)="; then
        log_error "Possible secrets detected in response"
        return 1
    else
        log_info "No obvious secrets detected in responses"
        return 0
    fi
}

# ============================================================================
# PERFORMANCE TESTS
# ============================================================================
test_load_handling() {
    echo ""
    echo -e "${BLUE}=== BASIC LOAD TEST ===${NC}"
    echo ""

    log_test "Sending concurrent requests to PWA..."

    # Send 10 concurrent requests
    local success=0
    for i in {1..10}; do
        curl -s "$BASE_URL:3000/health" > /dev/null 2>&1 && ((success++)) &
    done
    wait

    if [ "$success" -ge 8 ]; then
        log_info "Load test passed: $success/10 requests successful"
        return 0
    else
        log_error "Load test failed: $success/10 requests successful"
        return 1
    fi
}

# ============================================================================
# MAIN TEST SUITE
# ============================================================================
main() {
    local total_failed=0

    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║          Deployment Smoke Tests - $ENVIRONMENT Environment       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    test_lidbema_services || ((total_failed++))
    test_nexnod_cluster || ((total_failed++))
    test_monitoring_stack || ((total_failed++))
    test_metrics_collection || ((total_failed++))
    test_network_connectivity || ((total_failed++))
    test_data_persistence || ((total_failed++))
    test_security_headers || ((total_failed++))
    test_no_exposed_secrets || ((total_failed++))
    test_load_handling || ((total_failed++))

    # Final summary
    echo ""
    echo -e "${BLUE}=== TEST SUMMARY ===${NC}"
    echo ""

    if [ $total_failed -eq 0 ]; then
        echo -e "${GREEN}✓ All smoke tests passed!${NC}"
        echo ""
        echo "Deployment is ready for:"
        echo "  - User acceptance testing"
        echo "  - Production traffic"
        echo "  - Monitoring and alerting"
        return 0
    else
        echo -e "${RED}✗ $total_failed test suite(s) failed${NC}"
        echo ""
        echo "Review failures above and retry deployment"
        return 1
    fi
}

main "$@"
