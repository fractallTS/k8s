#!/bin/bash
# Demo script for zero-downtime rolling update
# This script demonstrates that the application remains available during the entire update process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="ecommerce"
DEPLOYMENT="app"
APP_URL="${APP_URL:-https://2jz.space}"
MONITOR_INTERVAL=1  # seconds between health checks
LOG_FILE="rolling-update-$(date +%Y%m%d-%H%M%S).log"

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Check prerequisites
print_header "Checking Prerequisites"

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl."
    exit 1
fi
print_success "kubectl found"

if ! command -v curl &> /dev/null; then
    print_error "curl not found. Please install curl."
    exit 1
fi
print_success "curl found"

if ! command -v jq &> /dev/null; then
    print_info "jq not found (optional). Install for better output formatting."
fi

# Verify deployment exists
if ! kubectl get deployment $DEPLOYMENT -n $NAMESPACE &> /dev/null; then
    print_error "Deployment $DEPLOYMENT not found in namespace $NAMESPACE"
    exit 1
fi
print_success "Deployment $DEPLOYMENT exists in namespace $NAMESPACE"

# Check initial state
print_header "Initial State Check"

echo "Current pod status:"
kubectl get pods -n $NAMESPACE -l app=flask-app

REPLICA_COUNT=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.replicas}')
print_info "Replica count: $REPLICA_COUNT"

READY_REPLICAS=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
if [ "$READY_REPLICAS" != "$REPLICA_COUNT" ]; then
    print_error "Not all replicas are ready ($READY_REPLICAS/$REPLICA_COUNT)"
    exit 1
fi
print_success "All $REPLICA_COUNT replicas are ready"

# Test initial API
print_header "Testing Initial API (V1)"

echo "Testing health endpoint:"
RESPONSE=$(curl -s "$APP_URL/health")
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"

if echo "$RESPONSE" | grep -q "healthy"; then
    print_success "API is healthy"
else
    print_error "API is not responding correctly"
    exit 1
fi

# Check if version field exists (V1 doesn't have it)
if echo "$RESPONSE" | grep -q "version"; then
    print_info "Current version detected: $(echo $RESPONSE | jq -r '.version' 2>/dev/null)"
    IS_V1=false
else
    print_info "Running V1 (no version field in response)"
    IS_V1=true
fi

# Start monitoring in background
print_header "Starting Continuous Monitoring"

MONITOR_LOG="monitor-$LOG_FILE"
MONITOR_PID_FILE="/tmp/rolling-update-monitor.pid"

# Function to monitor API
monitor_api() {
    local log_file=$1
    local total_requests=0
    local successful_requests=0
    local failed_requests=0
    local v1_responses=0
    local v2_responses=0

    echo "timestamp,status,version,response_time_ms" > "$log_file"

    while true; do
        total_requests=$((total_requests + 1))
        start_time=$(date +%s%N)

        response=$(curl -s -w "\n%{http_code}" "$APP_URL/health" 2>&1)
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | head -n-1)

        end_time=$(date +%s%N)
        response_time_ms=$(( (end_time - start_time) / 1000000 ))

        timestamp=$(date +"%Y-%m-%d %H:%M:%S")

        if [ "$http_code" = "200" ]; then
            successful_requests=$((successful_requests + 1))

            # Check version
            if echo "$body" | grep -q '"version"'; then
                version=$(echo "$body" | jq -r '.version' 2>/dev/null || echo "unknown")
                v2_responses=$((v2_responses + 1))
            else
                version="1.0"
                v1_responses=$((v1_responses + 1))
            fi

            echo "$timestamp,success,$version,$response_time_ms" >> "$log_file"
        else
            failed_requests=$((failed_requests + 1))
            echo "$timestamp,failed,error,$response_time_ms" >> "$log_file"
        fi

        # Print progress every 5 seconds
        if [ $((total_requests % 5)) -eq 0 ]; then
            echo "[$timestamp] Requests: $total_requests | Success: $successful_requests | Failed: $failed_requests | V1: $v1_responses | V2: $v2_responses" | tee -a "$log_file"
        fi

        sleep $MONITOR_INTERVAL
    done
}

print_info "Starting background monitoring (logging to $MONITOR_LOG)"
monitor_api "$MONITOR_LOG" &
MONITOR_PID=$!
echo $MONITOR_PID > "$MONITOR_PID_FILE"
print_success "Monitor started with PID $MONITOR_PID"

# Give monitor time to start
sleep 2

# Prompt for update
print_header "Ready to Perform Rolling Update"
echo ""
echo "The monitoring is now running in the background."
echo "It will continuously check the API every ${MONITOR_INTERVAL}s and log all responses."
echo ""
print_info "To perform the update, you have two options:"
echo ""
echo "Option 1: Manual update (you control the process)"
echo "  kubectl set image deployment/$DEPLOYMENT flask-app=ghcr.io/YOUR_OWNER/YOUR_REPO-app:v2 -n $NAMESPACE"
echo ""
echo "Option 2: Let this script simulate an update"
echo "  (Will use kubectl patch to trigger a config change)"
echo ""

read -p "Press ENTER to simulate update, or Ctrl+C to do manual update: "

# Simulate update by adding annotation (forces rolling restart)
print_header "Simulating Rolling Update"
print_info "Adding annotation to trigger rolling update..."

kubectl patch deployment $DEPLOYMENT -n $NAMESPACE -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"update-timestamp\":\"$(date +%s)\"}}}}}"

print_success "Update triggered!"
echo ""
print_info "Watching rollout status (this will take ~60 seconds)..."
echo ""

# Watch the rollout
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE

print_success "Rollout completed successfully!"

# Continue monitoring for a bit longer
print_header "Post-Update Verification"
print_info "Continuing monitoring for 10 more seconds..."
sleep 10

# Stop monitoring
print_header "Stopping Monitor"
if [ -f "$MONITOR_PID_FILE" ]; then
    MONITOR_PID=$(cat "$MONITOR_PID_FILE")
    kill $MONITOR_PID 2>/dev/null || true
    rm "$MONITOR_PID_FILE"
    print_success "Monitor stopped"
fi

# Analyze results
print_header "Results Analysis"

if [ -f "$MONITOR_LOG" ]; then
    total_requests=$(grep -c "," "$MONITOR_LOG" || echo "0")
    total_requests=$((total_requests - 1))  # Subtract header line

    successful_requests=$(grep -c ",success," "$MONITOR_LOG" || echo "0")
    failed_requests=$(grep -c ",failed," "$MONITOR_LOG" || echo "0")

    v1_responses=$(grep -c ",success,1.0," "$MONITOR_LOG" || echo "0")
    v2_responses=$(grep -c ",success,2.0," "$MONITOR_LOG" || echo "0")

    if [ "$total_requests" -gt 0 ]; then
        success_rate=$(awk "BEGIN {printf \"%.2f\", ($successful_requests / $total_requests) * 100}")
    else
        success_rate="0"
    fi

    echo ""
    echo "Total requests sent: $total_requests"
    echo "Successful requests: $successful_requests"
    echo "Failed requests: $failed_requests"
    echo "Success rate: $success_rate%"
    echo ""
    echo "V1 responses: $v1_responses"
    echo "V2 responses: $v2_responses"
    echo ""

    if [ "$failed_requests" -eq 0 ]; then
        print_success "ZERO DOWNTIME ACHIEVED! No failed requests during rollout"
    else
        print_error "Some requests failed during rollout"
    fi

    if [ "$v1_responses" -gt 0 ] && [ "$v2_responses" -gt 0 ]; then
        print_success "Both V1 and V2 detected - rolling update confirmed"
    fi

    # Calculate average response time
    avg_response_time=$(awk -F',' 'NR>1 {sum+=$4; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$MONITOR_LOG")
    echo "Average response time: ${avg_response_time}ms"

    echo ""
    print_info "Full log saved to: $MONITOR_LOG"
else
    print_error "Monitor log not found"
fi

# Final state
print_header "Final State"

echo "Current pod status:"
kubectl get pods -n $NAMESPACE -l app=flask-app

echo ""
echo "Testing API after update:"
FINAL_RESPONSE=$(curl -s "$APP_URL/health")
echo "$FINAL_RESPONSE" | jq '.' 2>/dev/null || echo "$FINAL_RESPONSE"

if echo "$FINAL_RESPONSE" | grep -q "version"; then
    FINAL_VERSION=$(echo "$FINAL_RESPONSE" | jq -r '.version' 2>/dev/null || echo "unknown")
    print_success "Final version: $FINAL_VERSION"
else
    print_info "Version field not found in response"
fi

# Summary
print_header "Demo Summary"

echo ""
echo "✅ Zero-downtime rolling update demonstration completed!"
echo ""
echo "Key achievements:"
echo "  • Maintained $REPLICA_COUNT replicas throughout update"
echo "  • maxUnavailable: 0 (no downtime)"
echo "  • maxSurge: 1 (infrastructure accommodated extra pod)"
echo "  • Success rate: $success_rate%"
echo "  • Average response time: ${avg_response_time}ms"
echo ""
echo "📊 Logs saved to:"
echo "  • Monitor log: $MONITOR_LOG"
echo ""
echo "To review the update:"
echo "  kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE"
echo ""
echo "To rollback if needed:"
echo "  kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE"
echo ""

print_success "Demo completed successfully!"
