#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

ANYTHINGLLM_VERSION="${ANYTHINGLLM_VERSION:-1.15.0}"
DMG_URL="https://github.com/Mintplex-Labs/anything-llm/releases/download/v${ANYTHINGLLM_VERSION}/AnythingLLMDesktop-Silicon.dmg"
APP_PATH="/Applications/AnythingLLM.app"
SEED_DIR="${CONFIG_DIR}/anythingllm"

log "Installing AnythingLLM desktop..."

if [[ -d "$APP_PATH" ]]; then
  log "AnythingLLM already installed"
else
  tmp_dmg="$(mktemp -t anythingllm.XXXXXX.dmg)"
  if ! curl -fL --retry 3 --retry-delay 5 -C - --progress-bar -o "$tmp_dmg" "$DMG_URL"; then
    die "AnythingLLM download failed (network). Retry: bash scripts/install-anythingllm.sh"
  fi
  mount_output="$(hdiutil attach "$tmp_dmg" -nobrowse 2>&1)"
  mount_point="$(echo "$mount_output" | awk -F'\t' '/\/Volumes\// {gsub(/^ +| +$/,"",$NF); print $NF; exit}')"
  if [[ -z "$mount_point" || ! -d "$mount_point" ]]; then
    mount_point="$(echo "$mount_output" | grep -o '/Volumes/[^[:space:]]*' | tail -1)"
  fi
  [[ -n "$mount_point" && -d "$mount_point" ]] || die "Failed to mount AnythingLLM DMG: $mount_output"
  app_src="$(find "$mount_point" -maxdepth 1 -name '*.app' | head -1)"
  [[ -n "$app_src" ]] || die "No .app in DMG at $mount_point"
  cp -R "$app_src" /Applications/
  hdiutil detach "$mount_point" -quiet || true
  rm -f "$tmp_dmg"
  log "Installed AnythingLLM to Applications"
fi

mkdir -p "$SEED_DIR"
load_omlx_env

cat > "${SEED_DIR}/workspace-setup.md" <<EOF
# AnythingLLM workspace setup

Complete these steps in the AnythingLLM app (opened automatically or from Applications).

## LLM provider

1. Open **Settings → LLM Preference**
2. Provider: **Generic OpenAI**
3. Base URL: \`${OMLX_BASE_URL:-http://127.0.0.1:8000/v1}\`
4. API Key: (from ${CONFIG_DIR}/omlx.env → OMLX_API_KEY)
5. Model: use a model name from oMLX admin, or Ollama tag \`qwen3.5:35b-a3b-coding-nvfp4\`

## Embedding provider (for RAG)

1. **Settings → Embedding Preference**
2. Provider: **Ollama**
3. Base URL: \`http://127.0.0.1:11434\`
4. Model: \`nomic-embed-text\`

## Create workspaces

| Name | Purpose |
|------|---------|
| Work | Employer/client documents only |
| Personal | Side projects and personal notes |

For each workspace:
- Set a distinct system prompt
- Upload documents only relevant to that workspace
- Do not mix work and personal files in one workspace

## Optional: Ollama fallback

If oMLX is busy, switch LLM provider to **Ollama** at \`http://127.0.0.1:11434\`.

See also: ${REPO_ROOT}/docs/work-personal-workflows.md
EOF

log "Workspace guide written to ${SEED_DIR}/workspace-setup.md"
open -a AnythingLLM 2>/dev/null || open -a "AnythingLLM.app" 2>/dev/null || true
log "Open AnythingLLM and follow ${SEED_DIR}/workspace-setup.md"
