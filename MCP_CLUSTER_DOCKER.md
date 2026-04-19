## Files Created

### 1. compose_docker.yml - Main compose file
Defines 6 services on a shared `mcp-cluster` network:

| Service | Image/Build | Port | Purpose |
|---------|------------|------|---------|
| `mcp-gateway` | tinymcp (built) | 8080 | Central gateway aggregating all MCP servers |
| `skillsmcp` | skillsmcp (built) | 3001 | FastMCP Skills Provider (streamable-http) |
| `desktop-commander` | `mcp/desktop-commander` | - | File system, shell, Docker tools |
| `wikipedia-mcp` | `mcp/wikipedia-mcp` | - | Wikipedia search & retrieval |
| `duckduckgo-mcp` | `mcp/duckduckgo` | - | Web search |
| `openbnb-airbnb` | `mcp/openbnb-airbnb` | - | Airbnb-style accommodation search |

### 2. start.sh - Start script
- Pre-flight checks (Docker, Compose)
- Auto-creates config files if missing
- Builds and starts all services
- Waits for gateway health check
- Shows client configuration snippet

### 3. stop.sh - Stop script
- Gracefully stops all containers
- Optional `--remove-images` / `-r` flag to clean up built images

### 4. Config files
- `config/tinymcp/config.json` - Gateway config pointing to skillsmcp at `http://skillsmcp:3001/mcp`
- `config/tinymcp/secrets.json` - Empty secrets store
- `config/skillsmcp/skills.settings.json` - Skills config pointing to `/home/user/.claude/skills`

### 5. `skills/` directory - Mount point for Claude Code skills

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
