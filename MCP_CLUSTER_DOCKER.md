## Files Created

### 1. compose_docker.yml - Main compose file
Defines 7 services on a shared `mcp-cluster` network:

| Service | Image/Build | Port | Purpose |
|---------|------------|------|---------|
| `mcp-gateway` | tinymcp (built) | 8080 | Central gateway aggregating all MCP servers |
| `skillsmcp` | skillsmcp (built) | 3001 | FastMCP Skills Provider (streamable-http) |
| `dema` | dema (built) | 8090 | MCP Control Plane (Deus Ex Machina) orchestration engine |
| `desktop-commander` | `mcp/desktop-commander` | - | File system, shell, Docker tools |
| `wikipedia-mcp` | `mcp/wikipedia-mcp` | - | Wikipedia search & retrieval |
| `duckduckgo-mcp` | `mcp/duckduckgo` | - | Web search |
| `openbnb-airbnb` | `mcp/openbnb-airbnb` | - | Airbnb-style accommodation search |

### 2. DEMA Integration

The DEMA (Deus Ex Machina) control plane is a multi-stage agentic workflow engine that:
- Connects to the MCP Gateway on the Docker network (`http://mcp-gateway:8080`)
- Provides a REST API on port 8090 for plan creation, execution, and monitoring
- Uses an LLM (configurable via `LLM_BASE_URL` env var) for autonomous decision-making
- Enforces deterministic state transitions and human-in-the-loop approval gates
- Maintains a 4-tier context hierarchy (P0-P3) for memory management

DEMA is configured via environment variables that can be overridden at runtime:
- `LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL_NAME` — LLM provider settings
- `MEMORY_P2_THRESHOLD`, `MEMORY_P3_TTL` — Memory management settings

### 3. start.sh - Start script
- Pre-flight checks (Docker, Compose)
- Auto-creates config files if missing
- Builds and starts all 7 services
- Waits for gateway health check
- Shows client configuration snippet

### 4. stop.sh - Stop script
- Gracefully stops all containers
- Optional `--remove-images` / `-r` flag to clean up built images

### 5. Config files
- `config/tinymcp/config.json` - Gateway config pointing to skillsmcp at `http://skillsmcp:3001/mcp`
- `config/tinymcp/secrets.json` - Empty secrets store
- `config/skillsmcp/skills.settings.json` - Skills config pointing to `/home/user/.claude/skills`

### 6. `skills/` directory - Mount point for Claude Code skills

## Usage

```bash
# Start the cluster
./start.sh

# Stop the cluster
./stop.sh

# Stop and remove built images
./stop.sh --remove-images
```

## MCP Client Configuration

Point your MCP client to the gateway:

```json
{
  "mcpServers": {
    "gateway": {
      "transport": "streamable-http",
      "url": "http://localhost:8080/mcp"
    }
  }
}
```

All tools from skillsmcp, desktop-commander, wikipedia, duckduckgo, and openbnb-airbnb will be available through the single gateway endpoint.

DEMA connects to the gateway separately via its REST API at `http://localhost:8090` to orchestrate multi-stage workflows using the aggregated tools.
