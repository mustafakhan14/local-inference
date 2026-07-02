#!/usr/bin/env bash
# One-shot: hub agents UI, terminal, download watcher, resume models
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

log "=== One-shot: Hub agents + downloads ==="

ensure_dirs
chmod +x "${REPO_ROOT}/scripts/"*.sh

bash "${REPO_ROOT}/scripts/install-host-scripts.sh"
bash "${REPO_ROOT}/scripts/install-agent-terminal.sh"

export OMLX_API_KEY="${OMLX_API_KEY:-mkapikey}"
if docker info >/dev/null 2>&1; then
  OMLX_API_KEY=mkapikey docker compose -f "${REPO_ROOT}/config/docker-compose.yml" up -d --build
else
  warn "Docker not running — start Docker Desktop"
fi

# Queue all incomplete downloads in background via watcher
echo '{"id":"all"}' > "${CONFIG_DIR}/download-request.json"

bash "${REPO_ROOT}/scripts/verify-setup.sh" || true

log ""
log "=== Done ==="
log "  Hub:          http://127.0.0.1:3080/hub"
log "  Downloads:    http://127.0.0.1:3080/hub/#downloads"
log "  Terminal:     http://127.0.0.1:3080/hub/#terminal"
log "  Hermes chat:  http://127.0.0.1:3080/hub/agents/hermes"
log "  OpenClaw chat: http://127.0.0.1:3080/hub/agents/openclaw"
