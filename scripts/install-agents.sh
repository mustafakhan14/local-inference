#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

log "Installing coding agents (OpenCode, wrappers)..."

if ! command_exists node; then
  brew install node
fi
if ! command_exists rg; then
  brew install ripgrep
fi

# OpenCode
if ! command_exists opencode; then
  npm install -g opencode-ai@latest 2>/dev/null || npm install -g opencode@latest 2>/dev/null || \
    warn "Install OpenCode manually: npm install -g opencode-ai"
fi

ensure_dirs
load_omlx_env
AGENTS_DIR="${CONFIG_DIR}/agents"
mkdir -p "$AGENTS_DIR" "${HOME}/.config/opencode"

# OpenCode config
PRIMARY_MODEL="${PRIMARY_MODEL:-qwen3.5:35b-a3b-coding-nvfp4}"
template="${REPO_ROOT}/config/opencode.json.template"
if [[ -f "$template" ]]; then
  sed -e "s|{{OMLX_API_KEY}}|${OMLX_API_KEY:-mkapikey}|g" \
      -e "s|{{PRIMARY_MODEL_ID}}|${PRIMARY_MODEL}|g" \
      "$template" > "${HOME}/.config/opencode/opencode.json"
  log "Wrote ~/.config/opencode/opencode.json"
fi

# Agent launcher scripts
write_agent() {
  local name="$1" body="$2"
  cat > "${AGENTS_DIR}/${name}.sh" <<EOF
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${AGENTS_DIR}/${name}.sh"
}

write_agent "opencode" '# OpenCode: terminal coding agent — repo edits, shell, multi-file
source "${HOME}/.config/local-inference/omlx.env"
export OPENCODE_DISABLE_CLAUDE_CODE=1
if command -v omlx >/dev/null 2>&1; then
  exec omlx launch opencode "$@"
fi
exec opencode "$@"'

write_agent "openclaw" '# OpenClaw: personal assistant — tasks, automation, messaging
source "${HOME}/.config/local-inference/omlx.env"
if command -v omlx >/dev/null 2>&1; then
  exec omlx launch openclaw --tools-profile coding "$@"
fi
exec openclaw "$@"'

write_agent "hermes" '# Hermes: general agent CLI via local Anthropic API
source "${HOME}/.config/local-inference/omlx.env"
export ANTHROPIC_BASE_URL="http://${OMLX_HOST}:${OMLX_PORT}"
export ANTHROPIC_AUTH_TOKEN="${OMLX_API_KEY}"
if command -v omlx >/dev/null 2>&1; then
  exec omlx launch hermes "$@" 2>/dev/null || true
fi
echo "Run: omlx launch hermes  (or oMLX admin → Applications → Hermes)"
exec "${HOME}/.config/local-inference/claude-local.sh" "$@"'

cat > "${CONFIG_DIR}/claude-local.sh" <<EOF
#!/usr/bin/env bash
source "\${HOME}/.config/local-inference/omlx.env"
export ANTHROPIC_BASE_URL="http://\${OMLX_HOST}:\${OMLX_PORT}"
export ANTHROPIC_AUTH_TOKEN="\${OMLX_API_KEY}"
exec claude "\$@"
EOF
chmod +x "${CONFIG_DIR}/claude-local.sh"

cat > "${CONFIG_DIR}/agents.env" <<EOF
export OPENCODE_DISABLE_CLAUDE_CODE=1
export ANTHROPIC_BASE_URL=http://127.0.0.1:8000
export ANTHROPIC_AUTH_TOKEN=${OMLX_API_KEY:-mkapikey}
EOF

log "Agent launchers in ${AGENTS_DIR}/"
log "  opencode.sh   — terminal coding agent"
log "  openclaw.sh   — personal assistant"
log "  hermes.sh     — general agent CLI"
