#!/bin/bash
#
# start.sh - Start the MCP cluster
#
# Usage: ./start.sh [--build] [--detach]
#
# Options:
#   --build    Force rebuild before starting
#   --detach   Run in detached mode (default)
#
# This script starts the full MCP cluster:
#   - tinymcp gateway (aggregates all MCP servers)
#   - skillsmcp server (Claude Code skills)
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
BUILD=false
DETACH="--detach"
for arg in "$@"; do
    case "$arg" in
        --build|-b)
            BUILD=true
            ;;
        --interactive|-i)
            DETACH=""
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --build, -b       Force rebuild before starting"
            echo "  --interactive, -i Run in interactive mode (not detached)"
            echo "  --help, -h        Show this help message"
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
        error "Run ./build.sh first to generate it."
        exit 1
    fi
    ok "Compose file found: ${COMPOSE_FILE}"
}

check_running() {
    local running
    running=$(docker compose -f "${COMPOSE_FILE}" -p "${COMPOSE_PROJECT_NAME}" ps --format name 2>/dev/null | head -1)
    if [[ -n "$running" ]]; then
        warn "Cluster is already running!"
        info "To restart, run: ./stop.sh && ./start.sh"
        info "To see status: docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} ps"
        exit 0
    fi
}

# ─── Prepare config ────────────────────────────────────────

prepare_config() {
    info "Preparing configuration..."

    mkdir -p "${SCRIPT_DIR}/config/tinymcp"
    mkdir -p "${SCRIPT_DIR}/config/skillsmcp"
    mkdir -p "${SCRIPT_DIR}/skills"

    # Gateway config
    if [[ ! -f "${SCRIPT_DIR}/config/tinymcp/config.json" ]]; then
        cat > "${SCRIPT_DIR}/config/tinymcp/config.json" <<'EOF'
{
  "mcpServers": {
    "skills-provider": {
      "transport": "streamable-http",
      "url": "http://skillsmcp:3001/mcp"
    }
  }
}
EOF
        ok "Created config/tinymcp/config.json"
    fi

    # Secrets
    if [[ ! -f "${SCRIPT_DIR}/config/tinymcp/secrets.json" ]]; then
        echo '{}' > "${SCRIPT_DIR}/config/tinymcp/secrets.json"
        ok "Created config/tinymcp/secrets.json"
    fi

    # Skills settings
    if [[ ! -f "${SCRIPT_DIR}/config/skillsmcp/skills.settings.json" ]]; then
        cat > "${SCRIPT_DIR}/config/skillsmcp/skills.settings.json" <<'EOF'
{
  "directories": ["/home/user/.claude/skills"],
  "reload": false,
  "supporting_files": "template",
  "http": {
    "enabled": true,
    "port": 3001,
    "host": "0.0.0.0",
    "path": "/mcp"
  },
  "gateway": {
    "enabled": false,
    "host": "localhost",
    "port": 8000,
    "name": "skills-provider",
    "transport": "streamable-http"
  }
}
EOF
        ok "Created config/skillsmcp/skills.settings.json"
    fi
}

# ─── Start cluster ─────────────────────────────────────────

start_cluster() {
    section "Starting MCP Cluster"

    info "Compose file: ${COMPOSE_FILE}"
    info "Project name: ${COMPOSE_PROJECT_NAME}"
    echo ""

    if [[ "$BUILD" == "true" ]]; then
        info "Building images..."
        docker compose -f "${COMPOSE_FILE}" -p "${COMPOSE_PROJECT_NAME}" build
        ok "Images built"
        echo ""
    fi

    info "Starting services..."
    docker compose -f "${COMPOSE_FILE}" -p "${COMPOSE_PROJECT_NAME}" up -d

    echo ""
    info "Waiting for services to initialize..."
    sleep 3
}

# ─── Health check ──────────────────────────────────────────

check_health() {
    info "Checking gateway health..."

    local retries=15
    local gateway_healthy=false
    while [[ $retries -gt 0 ]]; do
        if curl -sf "http://localhost:8080/healthz" &>/dev/null; then
            gateway_healthy=true
            break
        fi
        retries=$((retries - 1))
        sleep 2
    done

    if [[ "$gateway_healthy" == "true" ]]; then
        ok "MCP Gateway is healthy at http://localhost:8080"
    else
        warn "Gateway may not be fully ready. Check status:"
        warn "  docker compose -f ${COMPOSE_FILE} -p ${COMPOSE_PROJECT_NAME} ps"
    fi
}

# ─── Show status ───────────────────────────────────────────

show_status() {
    section "Cluster Status"

    info "Running services:"
    docker compose -f "${COMPOSE_FILE}" -p "${COMPOSE_PROJECT_NAME}" ps

    echo ""
    section "Access Points"

    echo -e "${GREEN}MCP Gateway:${NC}      http://localhost:8080"
    echo -e "${GREEN}Gateway API docs:${NC} http://localhost:8080/docs"
    echo -e "${GREEN}Skills Server:${NC}    http://localhost:3001/mcp"
    echo ""
    section "MCP Client Configuration"

    cat <<'EOF'
Add this to your MCP client config (e.g., Claude Code, Cursor, VS Code):

{
  "mcpServers": {
    "gateway": {
      "transport": "streamable-http",
      "url": "http://localhost:8080/mcp"
    }
  }
}

All MCP tools from all servers will be available through the gateway.
EOF
}

# ─── Main ───────────────────────────────────────────────────

main() {
    section "MCP Cluster - Start"

    check_compose_file
    check_running
    prepare_config
    start_cluster
    check_health
    show_status
}

main "$@"
