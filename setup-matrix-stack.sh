#!/bin/bash

################################################################################
# Matrix Synapse + Locust + OpenTelemetry Stack Setup Script
#
# This script sets up and manages the complete stack for load testing
# Matrix Synapse with observability through OpenTelemetry and Jaeger.
#
# Usage:
#   ./setup-matrix-stack.sh [command] [options]
#
# Commands:
#   init        Initialize the stack (download images, generate configs)
#   start       Start all containers
#   stop        Stop all containers
#   restart     Restart all containers
#   logs        View container logs
#   status      Show container status
#   clean       Stop and remove containers
#   destroy     Remove all volumes and data
#   help        Show this help message
#
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SCRIPT_DIR}"
CONFIG_DIR="${WORKSPACE_DIR}/config"
DATA_DIR="${WORKSPACE_DIR}/data"
ENV_FILE="${CONFIG_DIR}/.env"
COMPOSE_FILE="${WORKSPACE_DIR}/docker-compose.yml"

# Default values
COMMAND="${1:-help}"
VERBOSE=0

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_section() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

check_requirements() {
    log_section "Checking Requirements"
    
    local missing=0
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        missing=1
    else
        log_info "Docker: $(docker --version)"
    fi
    
    # Check for Docker Compose
    if ! command -v docker compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        missing=1
    else
        log_info "Docker Compose: $(docker compose --version 2>/dev/null || docker compose version)"
    fi
    
    # Check for required files
    if [ ! -f "${COMPOSE_FILE}" ]; then
        log_error "docker-compose.yml not found at ${COMPOSE_FILE}"
        missing=1
    else
        log_info "Found docker-compose.yml"
    fi
    
    if [ ! -f "${ENV_FILE}" ]; then
        log_error ".env file not found at ${ENV_FILE}"
        missing=1
    else
        log_info "Found .env configuration file"
    fi
    
    if [ ! -f "${CONFIG_DIR}/observability/otel-collector-config.yaml" ]; then
        log_error "OpenTelemetry collector config not found"
        missing=1
    else
        log_info "Found OpenTelemetry configuration"
    fi
    
    if [ ${missing} -eq 1 ]; then
        log_error "Some requirements are missing. Please check the output above."
        return 1
    fi
    
    log_success "All requirements met"
    return 0
}

create_directories() {
    log_section "Creating Directories"
    
    for dir in "${DATA_DIR}" "${DATA_DIR}/synapse" "${DATA_DIR}/postgres" "${DATA_DIR}/redis"; do
        if [ ! -d "${dir}" ]; then
            mkdir -p "${dir}"
            log_info "Created directory: ${dir}"
        fi
    done
    
    log_success "Directories ready"
}

initialize_synapse_config() {
    log_section "Initializing Synapse Configuration"
    
    # Synapse config is now mounted from config/synapse:/conf in docker-compose.yml
    # The SYNAPSE_CONFIG_PATH is set to /conf/homeserver.yaml
    # Therefore, no need to copy config to /data - it's purely for runtime files
    
    if [ ! -f "${CONFIG_DIR}/synapse/homeserver.yaml" ]; then
        log_error "Synapse configuration not found at ${CONFIG_DIR}/synapse/homeserver.yaml"
        log_error "Please ensure config/synapse/homeserver.yaml exists"
        return 1
    fi
    
    log_success "Synapse configuration ready (mounted from config/synapse to /conf in container)"
}

build_images() {
    log_section "Building Docker Images"
    
    log_info "Checking matrix-locust directory..."
    
    if [ ! -d "${WORKSPACE_DIR}/matrix-locust" ]; then
        log_error "matrix-locust directory not found at ${WORKSPACE_DIR}/matrix-locust"
        log_error "Cannot proceed without local matrix-locust bundle"
        return 1
    fi
    
    log_info "Found local matrix-locust directory ✓"
    log_info "Docker image will be built from local bundle when stack starts"
    log_success "Pre-flight checks passed - ready to build images on start"
}

init_stack() {
    log_section "Initializing Matrix Stack"
    
    check_requirements || return 1
    create_directories
    build_images
    initialize_synapse_config
    -,
    log_success "Stack initialization complete"
    log_info "Next steps:"
    echo -e "  1. Review and customize config files in ${CONFIG_DIR}/"
    echo -e "  2. Edit the .env file to adjust parameters (users, spawn rate, etc.)"
    echo -e "  3. Run '${SCRIPT_DIR}/setup-matrix-stack.sh start' to start the stack"
}

start_stack() {
    log_section "Starting Matrix Stack"
    
    check_requirements || return 1
    
    # Load environment variables from .env file
    if [ -f "${ENV_FILE}" ]; then
        set -a
        source "${ENV_FILE}"
        set +a
        log_info "Loaded environment variables from ${ENV_FILE}"
    fi
    
    log_info "Starting containers..."
    
    if docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up --watch; then
        log_success "Stack started successfully"
        
        log_info "Waiting for services to become healthy..."
        sleep 15
        
        log_section "Service Access Points"
        echo -e "  ${BLUE}Synapse${NC} (Matrix Homeserver)"
        echo -e "    URL: http://localhost:8008"
        echo ""
        echo -e "  ${BLUE}Locust${NC} (Load Tester Web UI)"
        echo -e "    URL: http://localhost:8089"
        echo ""
        echo -e "  ${BLUE}Jaeger${NC} (Trace Visualization)"
        echo -e "    URL: http://localhost:16686"
        echo ""
        echo -e "  ${BLUE}Prometheus${NC} (Metrics)"
        echo -e "    URL: http://localhost:9091"
        echo ""
        echo -e "  ${BLUE}Grafana${NC} (Dashboards)"
        echo -e "    URL: http://localhost:3000 (admin/admin)"
        echo ""
        
        log_info "Check logs with: ./setup-matrix-stack.sh logs [service-name]"
        
        # # Run quick tests
        # echo ""
        # if run_quick_tests; then
        #     echo ""
        #     log_section "Stack Ready"
        #     echo -e "  ${GREEN}✓ All services are healthy${NC}"
        #     echo -e "  ${GREEN}✓ Registration tests passed${NC}"
        #     echo ""
        #     echo -e "  You can now:"
        #     echo -e "    1. Open Locust at http://localhost:8089"
        #     echo -e "    2. Configure and run load tests"
        #     echo -e "    3. Monitor with Grafana at http://localhost:3000"
        # else
        #     log_warn "Quick tests failed. Stack is running but may have issues."
        # fi
    else
        log_error "Failed to start stack"
        return 1
    fi
}

stop_stack() {
    log_section "Stopping Matrix Stack"
    
    if docker compose -f "${COMPOSE_FILE}" down; then
        log_success "Stack stopped"
    else
        log_error "Failed to stop stack"
        return 1
    fi
}

restart_stack() {
    log_section "Restarting Matrix Stack"
    
    stop_stack || return 1
    sleep 2
    start_stack
}

show_status() {
    log_section "Stack Status"
    
    docker compose -f "${COMPOSE_FILE}" ps || log_error "Failed to get status"
}

run_quick_tests() {
    log_section "Running Quick Health Tests"
    
    local test_users=10
    local spawn_rate=1
    local run_time=20s
    
    log_info "These tests verify the stack is working correctly"
    echo ""
    
    # Change to workspace directory
    cd "${WORKSPACE_DIR}"
    
    # Step 1: Reset Database
    log_info "Step 1/3: Resetting Synapse database..."
    local reset_output
    reset_output=$(docker compose exec -T postgres psql -U synapse -d synapse << 'PSQL_EOF' 2>&1
TRUNCATE TABLE profiles CASCADE;
TRUNCATE TABLE users CASCADE;
TRUNCATE TABLE user_threepids CASCADE;
TRUNCATE TABLE access_tokens CASCADE;
TRUNCATE TABLE refresh_tokens CASCADE;
TRUNCATE TABLE deleted_pushers CASCADE;
TRUNCATE TABLE pushers CASCADE;
PSQL_EOF
)
    
    if [ $? -eq 0 ]; then
        log_success "✓ Database reset successful (cleared users and profiles)"
    else
        log_error "Failed to reset database"
        echo "$reset_output"
        return 1
    fi
    
    # Step 2: Generate Test Users
    log_info "Step 2/3: Generating ${test_users} test users..."
    if docker compose exec -T locust poetry run python generate_users.py ${test_users} > /dev/null 2>&1; then
        log_success "✓ Generated ${test_users} test users (user.000000 - user.000009)"
    else
        log_error "Failed to generate test users"
        return 1
    fi
    
    # Step 3: Run Registration Test
    log_info "Step 3/3: Running registration test (${test_users} users, ${spawn_rate}/sec spawn rate, ${run_time})..."
    
    local test_output_file="/tmp/locust_test_output_${RANDOM}.txt"
    rm -f "${test_output_file}"
    docker compose exec -T locust poetry run python -m locust \
        -f matrix_locust/client_server/register.py \
        --host=http://synapse:8008 \
        --headless --users=${test_users} --spawn-rate=${spawn_rate} --run-time=${run_time} > "${test_output_file}" 2>&1 &
    
    local locust_pid=$!
    sleep 35  # Wait for test to complete (20s + overhead)
    wait $locust_pid 2>/dev/null || true
    
    # Parse results
    local total_requests
    local failed_requests
    local success_rate
    
    if [ ! -f "${test_output_file}" ]; then
        log_warn "Test output file not found"
        return 1
    fi
    
    # Parse results - look for "Aggregated" line with final stats
    # Final line format: "Aggregated  <spaces>  <total> <failed>(<pct>)..."
    local total_requests=0
    local failed_requests=0
    
    # Get the final aggregated results line showing 0 failures
    local agg_line=$(grep -E "Aggregated.*0\(0\.00%\)" "${test_output_file}" | tail -1)
    
    if [ -n "$agg_line" ]; then
        # Extract the total requests (first number after Aggregated)
        total_requests=$(echo "$agg_line" | sed -E 's/.*Aggregated\s+([0-9]+).*/\1/')
        # Extract failed requests (should be 0)
        failed_requests=$(echo "$agg_line" | sed -E 's/.*Aggregated\s+[0-9]+\s+([0-9]+).*/\1/')
    fi
    
    if [ -z "${total_requests}" ] || [ "${total_requests}" -eq 0 ]; then
        log_warn "Could not parse test results - checking for any Aggregated line"
        tail -20 "${test_output_file}"
        return 1
    fi
    
    # Calculate success rate
    if [ "${failed_requests}" -eq 0 ]; then
        success_rate="100%"
    else
        success_rate=$(awk "BEGIN {printf \"%.1f%%\", ((${total_requests}-${failed_requests})/${total_requests})*100}")
    fi
    
    echo ""
    log_section "Test Results Summary"
    echo -e "  Total Requests: ${BLUE}${total_requests}${NC}"
    echo -e "  Failed Requests: ${BLUE}${failed_requests}${NC}"
    echo -e "  Success Rate: ${GREEN}${success_rate}${NC}"
    
    if [ "${failed_requests}" -eq 0 ]; then
        log_success "All tests passed! Stack is healthy and ready for load testing."
        return 0
    else
        log_warn "Some tests failed. Check logs with: ./setup-matrix-stack.sh logs synapse"
        return 1
    fi
}

show_logs() {
    local service="${2:-}"
    
    if [ -z "${service}" ]; then
        log_section "Stack Logs (All Services)"
        docker compose -f "${COMPOSE_FILE}" logs -f --tail=100
    else
        log_section "Logs for ${service}"
        docker compose -f "${COMPOSE_FILE}" logs -f --tail=100 "${service}"
    fi
}

clean_stack() {
    log_section "Cleaning Stack"
    
    log_warn "This will stop and remove all containers"
    read -p "Continue? (yes/no): " -r response
    
    if [[ "$response" =~ ^[Yy]es?$ ]]; then
        if docker compose -f "${COMPOSE_FILE}" down; then
            log_success "Containers removed"
        else
            log_error "Failed to clean stack"
            return 1
        fi
    else
        log_info "Cleanup cancelled"
    fi
}

destroy_stack() {
    log_section "Destroying Stack"
    
    log_warn "This will remove all containers and volumes, deleting all data"
    read -p "Type 'destroy' to confirm: " -r response
    
    if [ "${response}" = "destroy" ]; then
        if docker compose -f "${COMPOSE_FILE}" down -v; then
            log_success "Stack destroyed"
            
            # Remove data directories
            if [ -d "${DATA_DIR}" ]; then
                rm -rf "${DATA_DIR}"
                log_info "Removed data directory"
            fi
        else
            log_error "Failed to destroy stack"
            return 1
        fi
    else
        log_info "Destroy cancelled"
    fi
}

show_help() {
    cat << EOF

${BLUE}Matrix Synapse + Locust + OpenTelemetry Stack Manager${NC}

${BLUE}Usage:${NC}
  $0 [command] [options]

${BLUE}Commands:${NC}
  init            Initialize the stack (download images, generate configs)
  start           Start all containers
  stop            Stop all containers
  restart         Restart all containers
  logs [service]  View container logs (all services or specific service)
  status          Show container status
  clean           Stop and remove containers (keep volumes)
  destroy         Remove all containers and volumes (destructive!)
  help            Show this help message

${BLUE}Examples:${NC}
  $0 init
  $0 start
  $0 logs synapse
  $0 status
  $0 restart
  $0 stop

${BLUE}Configuration:${NC}
  - Edit ${CONFIG_DIR}/.env to customize settings
  - Edit ${CONFIG_DIR}/observability/otel-collector-config.yaml for OpenTelemetry settings
  - Edit ${CONFIG_DIR}/synapse/homeserver.yaml for Synapse settings

${BLUE}Documentation:${NC}
  See docs/MATRIX_STACK_SETUP.md for detailed information

EOF
}

################################################################################
# Main Script
################################################################################

main() {
    case "${COMMAND}" in
        init)
            init_stack
            ;;
        start)
            start_stack
            ;;
        stop)
            stop_stack
            ;;
        restart)
            restart_stack
            ;;
        logs)
            show_logs "$@"
            ;;
        status)
            show_status
            ;;
        clean)
            clean_stack
            ;;
        destroy)
            destroy_stack
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: ${COMMAND}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
