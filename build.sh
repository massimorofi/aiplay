#!/bin/bash
#
# build.sh - Build all Docker images for the MCP cluster
#
# Usage: ./build.sh
#
# Builds:
#   - tinymcp gateway (from ../tinymcp)
#   - skillsmcp server (from ../skillsmcp)
#   - Pulls all mcp/* Docker MCP server images
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-${SCRIPT_DIR}/compose_docker.yml}"

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

# ─── Pre-flight checks ─────────────────────────────────────

check_dependencies() {
    info "Checking dependencies..."
    local missing=()

    if ! command -v docker &>/dev/null; then
        missing+=("docker")
    elif ! docker compose version &>/dev/null; then
        missing+=("docker compose")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        error "Please install Docker and Docker Compose."
        exit 1
    fi
    ok "Docker and Docker Compose are available."
}

# ─── Verify source directories ─────────────────────────────

verify_sources() {
    info "Verifying source directories..."

    local TINY_MCP_DIR="${SCRIPT_DIR}/../tinymcp"
    local SKILLS_MCP_DIR="${SCRIPT_DIR}/../skillsmcp"

    if [[ ! -d "$TINY_MCP_DIR" ]] || [[ ! -f "${TINY_MCP_DIR}/Dockerfile" ]]; then
        error "tinymcp directory not found or missing Dockerfile at: ${TINY_MCP_DIR}"
        exit 1
    fi
    ok "tinymcp source: ${TINY_MCP_DIR}"

    if [[ ! -d "$SKILLS_MCP_DIR" ]] || [[ ! -f "${SKILLS_MCP_DIR}/Dockerfile" ]]; then
        error "skillsmcp directory not found or missing Dockerfile at: ${SKILLS_MCP_DIR}"
        exit 1
    fi
    ok "skillsmcp source: ${SKILLS_MCP_DIR}"
}

# ─── Prepare config files ──────────────────────────────────

prepare_config() {
    info "Preparing config files..."

    mkdir -p "${SCRIPT_DIR}/config/tinymcp"
    mkdir -p "${SCRIPT_DIR}/config/skillsmcp"
    mkdir -p "${SCRIPT_DIR}/skills"

    # Gateway config - point to skillsmcp on the Docker network
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

    # Secrets file
    if [[ ! -f "${SCRIPT_DIR}/config/tinymcp/secrets.json" ]]; then
        echo '{}' > "${SCRIPT_DIR}/config/tinymcp/secrets.json"
        ok "Created config/tinymcp/secrets.json"
    fi

    # Skills settings for the Docker container
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

# ─── Build images ──────────────────────────────────────────

build_images() {
    section "Building Custom Images"

    # Build tinymcp gateway
    info "Building tinymcp gateway..."
    docker compose -f "${COMPOSE_FILE}" -p mcp-cluster build mcp-gateway
    ok "tinymcp gateway built"

    # Build skillsmcp server
    info "Building skillsmcp server..."
    docker compose -f "${COMPOSE_FILE}" -p mcp-cluster build skillsmcp
    ok "skillsmcp server built"
}

# ─── Pull Docker MCP images ────────────────────────────────

pull_mcp_images() {
    section "Pulling Docker MCP Server Images"

    local mcp_images=(
        "mcp/desktop-commander:latest"
        "mcp/wikipedia-mcp:latest"
        "mcp/duckduckgo:latest"
        "mcp/openbnb-airbnb:latest"
    )

    for img in "${mcp_images[@]}"; do
        info "Pulling ${img}..."
        docker pull "$img"
        ok "${img} pulled"
    done
}

# ─── List built images ─────────────────────────────────────

list_images() {
    section "Built Images Summary"

    info "Custom images:"
    docker images "mcp-cluster-mcp-gateway" "mcp-cluster-skillsmcp" 2>/dev/null || true
    echo ""
    info "Docker MCP server images:"
    docker images "mcp/*" 2>/dev/null || true
}

# ─── Main ───────────────────────────────────────────────────

main() {
    section "MCP Cluster - Build All Images"

    check_dependencies
    verify_sources
    prepare_config
    build_images
    pull_mcp_images
    list_images

    section "Build Complete"
    info "All images built successfully."
    info "To start the cluster, run: ./start.sh"
}

main "$@"
