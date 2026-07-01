#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

log "Installing Ollama..."

if ! command_exists ollama; then
  brew install ollama
else
  log "Ollama already installed: $(ollama --version 2>/dev/null || true)"
fi

ensure_dirs
install_launchd_plist "com.ollama.serve"

# Prefer launchd; fall back to brew services if launchctl fails
if ! launchctl kickstart -k "gui/$(id -u)/com.ollama.serve" 2>/dev/null; then
  warn "launchd kickstart failed; trying brew services"
  brew services start ollama 2>/dev/null || true
fi

load_ollama_env
if wait_for_url "http://127.0.0.1:11434/api/tags" 20 2; then
  log "Ollama is running on 127.0.0.1:11434"
else
  warn "Ollama not yet reachable — it may start after login"
fi
