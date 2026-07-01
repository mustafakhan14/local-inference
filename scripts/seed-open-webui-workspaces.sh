#!/usr/bin/env bash
# Seed Open WebUI Work/Personal knowledge collection setup guide
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

SEED_DIR="${CONFIG_DIR}/open-webui"
mkdir -p "$SEED_DIR"

cat > "${SEED_DIR}/workspaces.md" <<'EOF'
# Open WebUI — Work & Personal setup

After first login at http://127.0.0.1:3080:

## Knowledge Collections (replaces AnythingLLM)

1. Go to **Workspace** → **Knowledge**
2. Create collection **Work** — upload work docs, specs, runbooks
3. Create collection **Personal** — personal notes, recipes, etc.
4. In chat, attach a collection via **#** or the knowledge picker

## Models

- Primary (oMLX): Qwen 35B when loaded in oMLX admin
- Fallback (Ollama): qwen2.5-coder:14b, qwen3.5:35b-a3b-coding-nvfp4

## Stack Hub

Status, agents, downloads: http://127.0.0.1:3080/hub
EOF

log "Open WebUI workspace guide: ${SEED_DIR}/workspaces.md"
log "Create Work + Personal Knowledge Collections in Open WebUI after first login"
