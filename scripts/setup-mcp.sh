#!/usr/bin/env bash
# Install MCP servers for local agent workflows (filesystem, git, fetch)
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

log "Setting up MCP servers for agent workflows..."

if ! command_exists node; then
  brew install node
fi

MCP_DIR="${CONFIG_DIR}/mcp"
mkdir -p "$MCP_DIR"

# Cursor MCP config
CURSOR_MCP="${HOME}/.cursor/mcp.json"
PROJECTS_DIR="${HOME}/Documents/GitHub"

backup_if_exists() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp "$f" "${f}.bak.$(date +%s)"
  fi
}

write_cursor_mcp() {
  backup_if_exists "$CURSOR_MCP"
  cat > "$CURSOR_MCP" <<EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "${PROJECTS_DIR}"]
    },
    "git": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-git", "--repository", "${REPO_ROOT}"]
    },
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    }
  }
}
EOF
  log "Wrote Cursor MCP config: ${CURSOR_MCP}"
}

write_cursor_mcp

# oMLX MCP note — enable in oMLX admin if using oMLX-native MCP tools
cat > "${MCP_DIR}/README.md" <<EOF
# MCP setup

## Cursor (installed)

Config: \`~/.cursor/mcp.json\`

Restart Cursor after changes. MCP tools work with **Agent mode** when your selected model supports tool calling.

## oMLX built-in MCP

oMLX supports MCP tool integration natively. Enable in:
http://127.0.0.1:8000/admin → Settings → MCP

Pair with Qwen 3.5+ for reliable tool calling.

## Open WebUI

Open WebUI supports MCP via Settings → Admin → MCP Servers.
Stack Hub: http://127.0.0.1:3080/hub
EOF

log "MCP setup complete. Restart Cursor to load MCP servers."
