#!/usr/bin/env bash
# Complete interrupted bootstrap: services, models, stack hub, oMLX config
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

log "=== Finishing local inference setup (one-shot) ==="

# Ensure API key
mkdir -p "${CONFIG_DIR}"
if [[ ! -f "${CONFIG_DIR}/omlx.env" ]]; then
  cat > "${CONFIG_DIR}/omlx.env" <<EOF
OMLX_HOST=127.0.0.1
OMLX_PORT=8000
OMLX_MODEL_DIR=${HOME}/models
OMLX_API_KEY=mkapikey
OMLX_BASE_URL=http://127.0.0.1:8000/v1
OMLX_ADMIN_URL=http://127.0.0.1:8000/admin
EOF
  chmod 600 "${CONFIG_DIR}/omlx.env"
fi

load_omlx_env
export OMLX_API_KEY="${OMLX_API_KEY:-mkapikey}"

bash "${REPO_ROOT}/scripts/configure-omlx.sh"
bash "${REPO_ROOT}/scripts/setup-mcp.sh"
bash "${REPO_ROOT}/scripts/install-agents.sh"

# Retire broken :8765 dashboard launchd agent
launchctl bootout "gui/$(id -u)/com.local-inference.dashboard" 2>/dev/null || true
rm -f "${HOME}/Library/LaunchAgents/com.local-inference.dashboard.plist"

# Docker stack (Caddy + Open WebUI + Stack Hub)
if docker info >/dev/null 2>&1; then
  docker rm -f open-webui local-inference-gateway local-inference-caddy stack-hub 2>/dev/null || true
  docker compose -f "${REPO_ROOT}/config/docker-compose.yml" up -d --build
  bash "${REPO_ROOT}/scripts/seed-open-webui-workspaces.sh" || true
else
  warn "Docker not running — start Docker Desktop, then: make start"
fi

# Model downloads (resumable)
bash "${REPO_ROOT}/scripts/pull-models.sh" || warn "Some model downloads incomplete — check /hub"

bash "${REPO_ROOT}/scripts/configure-cursor.sh"
bash "${REPO_ROOT}/scripts/verify-setup.sh" || true

log ""
log "=== Done ==="
log "  Bookmark:  http://127.0.0.1:3080/hub"
log "  Chat:      http://127.0.0.1:3080"
log "  oMLX:      http://127.0.0.1:3080/omlx/admin"
log "  API key:   mkapikey"
