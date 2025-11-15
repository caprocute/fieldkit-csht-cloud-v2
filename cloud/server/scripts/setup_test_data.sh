#!/bin/bash

# Script để setup dữ liệu test tự động cho FieldKit

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DB_URL="${FIELDKIT_POSTGRES_URL:-postgres://fieldkit:password@localhost:5432/fieldkit?sslmode=disable}"
API_URL="${FIELDKIT_API_URL:-http://localhost:8080}"
STATIONS="${STATIONS:-5}"
READINGS="${READINGS:-1000}"
INTERVAL="${INTERVAL:-5m}"
BATCH="${BATCH:-10}"

# Functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# Check dependencies
check_command go
check_command curl
check_command jq

# Build tools
print_info "Building tools..."
cd "$(dirname "$0")/.."
go build -o bin/seed cmd/seed/seed.go
go build -o bin/api-client cmd/api_client/api_client.go
go build -o bin/hardware-sim cmd/hardware_sim/hardware_sim.go
print_info "Tools built successfully"

# Step 1: Seed database
print_info "Step 1: Seeding database..."
./bin/seed \
    -db="$DB_URL" \
    -stations="$STATIONS" \
    -readings="$READINGS" \
    -user="floodnet@test.local" \
    -name="FloodNet Test User" \
    -password="test123456"

if [ $? -ne 0 ]; then
    print_error "Failed to seed database"
    exit 1
fi

print_info "Database seeded successfully"

# Step 2: Get JWT token
print_info "Step 2: Getting JWT token..."
TOKEN=$(curl -s -X POST "$API_URL/user/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"floodnet@test.local","password":"test123456"}' \
    | jq -r '.token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    print_error "Failed to get JWT token. Please check API is running."
    exit 1
fi

print_info "JWT token obtained"

# Step 3: Start hardware simulators
print_info "Step 3: Starting hardware simulators..."
print_warn "Press Ctrl+C to stop all simulators"

# Create logs directory
mkdir -p logs

# Start simulators in background
declare -a SIM_PIDS
for i in $(seq 1 $STATIONS); do
    print_info "Starting simulator for Station $i..."
    ./bin/hardware-sim \
        -api="$API_URL" \
        -token="$TOKEN" \
        -station="FloodNet Station $i" \
        -interval="$INTERVAL" \
        -batch="$BATCH" \
        > "logs/simulator-$i.log" 2>&1 &
    SIM_PIDS[$i]=$!
done

# Wait for user interrupt
cleanup() {
    print_info "Stopping simulators..."
    for pid in "${SIM_PIDS[@]}"; do
        if [ ! -z "$pid" ]; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    exit
}

trap cleanup INT TERM

print_info "All simulators started. PIDs: ${SIM_PIDS[*]}"
print_info "Logs are in logs/simulator-*.log"
print_info "Press Ctrl+C to stop"

# Wait for all background processes
wait

