#!/usr/bin/env bash
# Apply recommended oMLX settings for agent workloads on M4 Pro 48GB
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

load_omlx_env
API_KEY="${OMLX_API_KEY:-mkapikey}"
BASE="http://${OMLX_HOST:-127.0.0.1}:${OMLX_PORT:-8000}"

log "Configuring oMLX for agent workloads..."

# Login to admin API
login_resp="$(curl -sf -X POST "${BASE}/api/login" \
  -H "Content-Type: application/json" \
  -d "{\"api_key\":\"${API_KEY}\"}" 2>/dev/null || true)"

# Update global settings (best-effort — requires session cookie from login)
SETTINGS_PAYLOAD=$(cat <<'JSON'
{
  "idle_timeout_seconds": 3600,
  "max_concurrent_requests": 8,
  "memory_guard_tier": "balanced",
  "chunked_prefill": true,
  "hot_cache_max_size": "20%",
  "ssd_cache_enabled": true,
  "max_context_window": 32768,
  "sse_keepalive_mode": "chunk",
  "burst_decode_mode": "balanced",
  "preserve_mid_system_cache": true
}
JSON
)

# Patch ~/.omlx/settings.json directly (reliable for menubar app)
SETTINGS_FILE="${HOME}/.omlx/settings.json"
if [[ -f "$SETTINGS_FILE" ]] && command_exists jq; then
  mkdir -p "${HOME}/models" "${HOME}/.omlx/cache"
  tmp="$(mktemp)"
  jq --arg home "$HOME" --arg key "$API_KEY" '
    .auth.api_key = $key |
    .auth.skip_api_key_verification = false |
    .server.host = "127.0.0.1" |
    .server.auto_start_on_launch = true |
    .server.sse_keepalive_mode = "chunk" |
    .server.burst_decode_mode = "balanced" |
    .server.preserve_mid_system_cache = true |
    .model.model_dirs = [($home + "/.omlx/models"), ($home + "/models")] |
    .model.model_dir = ($home + "/models") |
    .memory.memory_guard_tier = "balanced" |
    .memory.prefill_memory_guard = true |
    .scheduler.max_concurrent_requests = 8 |
    .scheduler.chunked_prefill = true |
    .cache.enabled = true |
    .cache.hot_cache_only = false |
    .cache.ssd_cache_dir = ($home + "/.omlx/cache") |
    .cache.hot_cache_max_size = "20%" |
    .sampling.max_context_window = 32768 |
    .sampling.max_tokens = 8192
  ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  log "Updated ${SETTINGS_FILE}"
fi

# Symlink Ollama models dir hint for oMLX discovery
if [[ -d "${HOME}/.ollama/models" && ! -L "${HOME}/models/ollama" ]]; then
  ln -sf "${HOME}/.ollama/models" "${HOME}/models/ollama-gguf" 2>/dev/null || true
fi

log "oMLX configured. Restart oMLX from menu bar to apply (or: omlx restart)"
log "Admin: ${BASE}/admin"
log "API key: ${API_KEY} (saved in ~/.config/local-inference/omlx.env)"
