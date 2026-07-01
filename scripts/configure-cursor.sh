#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

load_omlx_env
API_KEY="${OMLX_API_KEY:-mkapikey}"
BASE_URL="${OMLX_BASE_URL:-http://127.0.0.1:8000/v1}"

PRIMARY_MODEL="${1:-qwen3.5:35b-a3b-coding-nvfp4}"

# Try to detect loaded oMLX model
if curl -sf -H "Authorization: Bearer ${API_KEY}" "http://127.0.0.1:8000/v1/models" 2>/dev/null | jq -e '.data[0].id' >/dev/null 2>&1; then
  detected="$(curl -sf -H "Authorization: Bearer ${API_KEY}" "http://127.0.0.1:8000/v1/models" | jq -r '.data[0].id')"
  [[ -n "$detected" && "$detected" != "null" ]] && PRIMARY_MODEL="$detected"
fi

mkdir -p "${CONFIG_DIR}"
cat > "${CONFIG_DIR}/cursor-settings.md" <<EOF
# Cursor — local agent setup (copy these into Cursor Settings → Models)

## Required settings

| Setting | Value |
|---------|-------|
| Override OpenAI Base URL | \`${BASE_URL}\` |
| OpenAI API Key | \`${API_KEY}\` |
| Model name (add model) | \`${PRIMARY_MODEL}\` |

## Steps

1. Open **Cursor Settings** (Cmd+,) → **Models**
2. Enable **Override OpenAI Base URL** → paste URL above
3. Paste API key: \`${API_KEY}\`
4. Click **Add model** → enter: \`${PRIMARY_MODEL}\`
5. **Select only this model** for Chat and Agent
6. **Disable all cloud models** when working on private data
7. Use **Agent mode** (not Ask) for tool-calling workflows
8. Restart Cursor after MCP setup (\`make setup-mcp\`)

## Ollama fallback (if oMLX model not loaded yet)

| Setting | Value |
|---------|-------|
| Base URL | \`http://127.0.0.1:11434/v1\` |
| API Key | \`ollama\` |
| Model | \`qwen2.5-coder:14b\` |

## Limits

- **Tab autocomplete** stays cloud-only (Cursor limitation)
- Local Agent quality ≈ Qwen 35B, not Claude Fable 5 frontier

Saved: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
chmod 600 "${CONFIG_DIR}/cursor-settings.md"

# MCP for Cursor agents
bash "$(dirname "$0")/setup-mcp.sh" 2>/dev/null || true

cat <<EOF

================================================================================
CURSOR LOCAL AGENT — apply these now
================================================================================

  Base URL:  ${BASE_URL}
  API Key:   ${API_KEY}
  Model:     ${PRIMARY_MODEL}

  1. Cursor Settings → Models → Override OpenAI Base URL
  2. Add model: ${PRIMARY_MODEL}
  3. Switch this chat to that model (model picker top of chat)
  4. Use Agent mode for tool use (like this conversation)

  Full guide: ~/.config/local-inference/cursor-settings.md

================================================================================

EOF

log "Cursor config saved to ${CONFIG_DIR}/cursor-settings.md"
