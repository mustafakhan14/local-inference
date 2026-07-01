#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

log "Installing Open WebUI + Stack Hub via Docker..."

if ! command_exists docker; then
  log "Installing Docker Desktop formula (cask)..."
  brew install --cask docker
  warn "Docker Desktop installed. Start Docker Desktop from Applications, then re-run: make start"
fi

if ! docker info >/dev/null 2>&1; then
  warn "Docker daemon not running. Start Docker Desktop, then: make start"
  exit 0
fi

load_omlx_env
export OMLX_API_KEY="${OMLX_API_KEY:-mkapikey}"

compose_file="${REPO_ROOT}/config/docker-compose.yml"
docker compose -f "$compose_file" pull open-webui 2>/dev/null || true
docker compose -f "$compose_file" up -d --build

if wait_for_url "http://127.0.0.1:3080" 30 3; then
  log "Stack running at http://127.0.0.1:3080"
  log "  Hub:  http://127.0.0.1:3080/hub"
  log "  Chat: http://127.0.0.1:3080"
else
  warn "Stack started but not yet reachable on :3080"
  docker compose -f "$compose_file" ps
fi
