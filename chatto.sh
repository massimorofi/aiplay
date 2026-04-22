#!/bin/bash
# Run chatto.py inside the tinymcp-gateway container
# With network_mode: host, localhost inside the container = localhost on the host
#   - MCP_GATEWAY_URL=http://localhost:8080 (gateway is on same container)
#   - LMSTUDIO_URL=http://localhost:1234 (LM Studio on host is directly accessible)
docker exec -i \
  -e MCP_GATEWAY_URL=http://localhost:8080 \
  -e LMSTUDIO_URL=http://localhost:1234 \
  tinymcp-gateway\
  python3 /app/agents/chatto/chatto.py

