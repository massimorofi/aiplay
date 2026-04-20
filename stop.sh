#!/bin/bash
#
# stop.sh - Stop the MCP cluster
#
# Usage: ./stop.sh [--remove-images]
#
# Options:
#   --remove-images, -r   Also remove built images
#   --help, -h            Show this help message
#
# This script stops the full MCP cluster:
#   - tinymcp gateway
#   - skillsmcp server
#   - dema control plane
#   - Desktop Commander MCP
#   - Wikipedia MCP
#   - DuckDuckGo MCP
#   - OpenBnB Airbnb MCP
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-${SCRIPT_DIR}/compose_docker.yml}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-mcp-cluster}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
section() { echo -e "\n${CYAN}══════════════════════════════════════════════${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}══════════════════════════════════════════════${NC}\n"; }

# Parse arguments
REMOVE_IMAGES=false
for arg in "$@"; do
    case "$arg" in
        --remove-images|-r)
            REMOVE_IMAGES=true
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --remove-images, -r   Also remove built images"
            echo "  --help, -h            Show this help message"
            exit 0
            ;;
        *)
            warn "Unknown argument: $arg"
            ;;
    esac
done

# ─── Pre-flight checks ─────────────────────────────────────

check_compose_file() {
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        error "Compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi
}

check_running() {
    local running
    running=$(docker compose -f "${COMPOSE_FILE}" -p "${COMPOSE_PROJECT_NAME}" ps --format name 2>/dev/null | head -1)
    if [[ -z "$running" ]]; then
        warn "No MCP cluster containers are running."
        info "If you believe this is incorrect, check with:"
        info "  docker ps --filter name=mcp-cluster"
        exit 0
    fi
    ok "Found running cluster"
}

# ─── Stop cluster ──────────────────────────────────────────

stop_cluster() {
    section "Stopping MCP Cluster"

    info "Stopping services..."
    docker compose -f "${COMPOSE_FILE}" -p "${COMPOSE_PROJECT_NAME}" down

    ok "MCP cluster stopped"
}

# ─── Remove images ─────────────────────────────────────────

remove_images() {
    if [[ "$REMOVE_IMAGES" == "true" ]]; then
        section "Removing Built Images"
        info "Removing custom images..."
        docker compose -f "${COMPOSE_FILE}" -p "${COMPOSE_PROJECT_NAME}" down --rmi all
        ok "Built images removed"
    fi
}

# ─── Show status ───────────────────────────────────────────

show_status() {
    section "Cluster Status"

    info "Current state:"
    docker compose -f "${COMPOSE_FILE}" -p "${COMPOSE_PROJECT_NAME}" ps 2>/dev/null || echo "  No containers running"

    echo ""
    info "To start the cluster again, run:"
    info "  ./start.sh"
}

# ─── Main ───────────────────────────────────────────────────

main() {
    section "MCP Cluster - Stop"

    check_compose_file
    check_running
    stop_cluster
    remove_images
    show_status
}

main "$@"
