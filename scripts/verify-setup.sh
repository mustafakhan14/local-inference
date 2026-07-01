#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

PASS=0
FAIL=0

check() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    log "OK  $name"
    PASS=$((PASS + 1))
  else
    warn "FAIL $name"
    FAIL=$((FAIL + 1))
  fi
}

log "Verifying local inference stack..."
echo ""

load_omlx_env
load_ollama_env

check "Ollama API" "curl -sf http://127.0.0.1:11434/api/tags"
check "oMLX health" "curl -sf http://127.0.0.1:8000/health || curl -sf -H 'Authorization: Bearer ${OMLX_API_KEY}' http://127.0.0.1:8000/v1/models"
check "Stack Hub API" "curl -sf http://127.0.0.1:3080/hub/api/status"
check "Open WebUI" "curl -sf http://127.0.0.1:3080"
check "Docker running" "docker info"
check "oMLX config" "test -f ${CONFIG_DIR}/omlx.env"
check "Model dir" "test -d ${HOME}/models"
check "Ollama binary" "command -v ollama"
check "oMLX app" "test -d /Applications/oMLX.app"
check "Gateway container" "docker ps --format '{{.Names}}' | grep -q local-inference-gateway"

if command_exists ollama; then
  if ollama list 2>/dev/null | grep -q "qwen"; then
    log "OK  Ollama has Qwen model(s)"
    PASS=$((PASS + 1))
  else
    warn "FAIL Ollama Qwen models not pulled yet (run: make update-models)"
    FAIL=$((FAIL + 1))
  fi
fi

# Smoke test Ollama generation (fast model if available)
if curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  fast_model="qwen2.5-coder:14b"
  if ollama list 2>/dev/null | grep -q "qwen2.5-coder"; then
    log "Running Ollama smoke test (${fast_model})..."
    if ollama run "$fast_model" "Say hi in 3 words" --nowordwrap 2>/dev/null | head -1 | grep -q .; then
      log "OK  Ollama smoke test"
      PASS=$((PASS + 1))
    else
      warn "FAIL Ollama smoke test"
      FAIL=$((FAIL + 1))
    fi
  fi
fi

echo ""
log "Results: ${PASS} passed, ${FAIL} failed"

if [[ "$FAIL" -gt 0 ]]; then
  log "See http://127.0.0.1:3080/hub and docs/troubleshooting.md"
  exit 1
fi

log "Stack healthy. Hub: http://127.0.0.1:3080/hub"
