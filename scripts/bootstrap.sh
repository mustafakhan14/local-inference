#!/usr/bin/env bash
# One-shot bootstrap for M4 Pro local AI stack
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

SKIP_MODELS="${SKIP_MODELS:-0}"
SKIP_DOCKER="${SKIP_DOCKER:-0}"

log "=========================================="
log " Local Inference Stack — Bootstrap"
log " Repo: ${REPO_ROOT}"
log "=========================================="

ensure_dirs
touch "${STATE_FILE}"
echo "BOOTSTRAP_STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${STATE_FILE}"

# 1. Homebrew dependencies
log "[1/8] Installing Homebrew dependencies..."
deps=(jq curl yq)
for dep in "${deps[@]}"; do
  if ! command_exists "$dep"; then
    brew install "$dep"
  fi
done

if [[ "$SKIP_DOCKER" != "1" ]]; then
  if ! command_exists docker; then
    log "Installing Docker Desktop (required for Open WebUI + Stack Hub)..."
    brew install --cask docker || warn "Docker install failed — install manually and re-run"
  fi
fi

if ! command_exists node; then
  brew install node
fi
if ! command_exists rg; then
  brew install ripgrep
fi

# 2. Ollama
log "[2/8] Ollama..."
bash "${SCRIPT_DIR}/install-ollama.sh"

# 3. oMLX
log "[3/8] oMLX..."
bash "${SCRIPT_DIR}/install-omlx.sh"

# 4. LM Studio (optional manual)
log "[4/8] LM Studio (optional)..."
if [[ -d "/Applications/LM Studio.app" ]]; then
  log "LM Studio already installed"
else
  warn "LM Studio not installed — optional model browser for ~/models"
  warn "Download: https://lmstudio.ai/"
fi

# 5. Models
if [[ "$SKIP_MODELS" != "1" ]]; then
  log "[5/8] Pulling models (may take 30–90 min)..."
  bash "${SCRIPT_DIR}/pull-models.sh"
else
  log "[5/8] Skipping model pull (SKIP_MODELS=1)"
fi

# 6. launchd already installed by ollama/omlx scripts
log "[6/8] Launch agents installed"

# 7. Docker stack (Open WebUI + Stack Hub + Caddy)
if [[ "$SKIP_DOCKER" != "1" ]]; then
  log "[7/8] Docker stack (Open WebUI + Hub)..."
  bash "${SCRIPT_DIR}/install-open-webui.sh"
  bash "${SCRIPT_DIR}/seed-open-webui-workspaces.sh" || true
else
  log "[7/8] Skipping Docker stack (SKIP_DOCKER=1)"
fi

# 8. Agents + Cursor config
log "[8/8] Agents and Cursor config..."
bash "${SCRIPT_DIR}/install-agents.sh"
bash "${SCRIPT_DIR}/configure-omlx.sh"
bash "${SCRIPT_DIR}/setup-mcp.sh"
bash "${SCRIPT_DIR}/configure-cursor.sh"

# Retire legacy :8765 dashboard
launchctl bootout "gui/$(id -u)/com.local-inference.dashboard" 2>/dev/null || true
rm -f "${HOME}/Library/LaunchAgents/com.local-inference.dashboard.plist"

echo "BOOTSTRAP_FINISHED=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${STATE_FILE}"

log ""
log "=========================================="
log " Bootstrap complete"
log "=========================================="
log "  Bookmark:  http://127.0.0.1:3080/hub"
log "  Chat:      http://127.0.0.1:3080"
log "  oMLX:      http://127.0.0.1:3080/omlx/admin"
log "  API key:   ${CONFIG_DIR}/omlx.env"
log "  Cursor guide:  ${CONFIG_DIR}/cursor-settings.md"
log ""
log "Run: make verify"
log ""

bash "${SCRIPT_DIR}/verify-setup.sh" || warn "Some checks failed — see docs/troubleshooting.md"
