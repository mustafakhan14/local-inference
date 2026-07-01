#!/usr/bin/env bash
# Shared helpers for local-inference scripts

set -euo pipefail

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "${_script_dir}/../.." && pwd)"
elif [[ -n "${REPO_ROOT:-}" ]]; then
  : # preserve REPO_ROOT from Makefile/caller
else
  REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi
CONFIG_DIR="${HOME}/.config/local-inference"
LOG_DIR="${HOME}/Library/Logs/local-inference"
STATE_FILE="${CONFIG_DIR}/state.env"

export REPO_ROOT CONFIG_DIR LOG_DIR STATE_FILE

log()  { printf '[local-inference] %s\n' "$*"; }
warn() { printf '[local-inference] WARN: %s\n' "$*" >&2; }
die()  { printf '[local-inference] ERROR: %s\n' "$*" >&2; exit 1; }

ensure_dirs() {
  mkdir -p "$CONFIG_DIR" "$LOG_DIR" "${HOME}/models"
}

load_omlx_env() {
  if [[ -f "${CONFIG_DIR}/omlx.env" ]]; then
    # shellcheck disable=SC1091
    set -a
    source "${CONFIG_DIR}/omlx.env"
    set +a
  fi
}

load_ollama_env() {
  if [[ -f "${REPO_ROOT}/config/ollama.env" ]]; then
    # shellcheck disable=SC1091
    set -a
    source "${REPO_ROOT}/config/ollama.env"
    set +a
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

macos_major_version() {
  sw_vers -productVersion | cut -d. -f1
}

wait_for_url() {
  local url="$1"
  local retries="${2:-30}"
  local delay="${3:-2}"
  local i
  for ((i = 1; i <= retries; i++)); do
    if curl -sf "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$delay"
  done
  return 1
}

install_launchd_plist() {
  local name="$1"
  local src="${REPO_ROOT}/config/launchd/${name}.plist"
  local dst="${HOME}/Library/LaunchAgents/${name}.plist"
  [[ -f "$src" ]] || die "Missing plist: $src"
  sed -e "s|__REPO_ROOT__|${REPO_ROOT}|g" -e "s|__HOME__|${HOME}|g" "$src" > "$dst"
  launchctl bootout "gui/$(id -u)/${name}" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$dst"
  launchctl enable "gui/$(id -u)/${name}" 2>/dev/null || true
  log "Installed launchd agent: ${name}"
}

catalog_ollama_models() {
  local catalog="${REPO_ROOT}/models/catalog.yaml"
  [[ -f "$catalog" ]] || die "Missing catalog: $catalog"
  if command_exists yq; then
    yq -r '.models[] | select(.backends == "ollama" or .backends == "both") | .ollama' "$catalog" | sort -u
  else
    grep 'ollama:' "$catalog" | sed 's/.*ollama: //' | tr -d ' ' | sort -u
  fi
}

catalog_omlx_hf_models() {
  local catalog="${REPO_ROOT}/models/catalog.yaml"
  if command_exists yq; then
    yq -r '.models[] | select(.omlx_hf != null) | .omlx_hf' "$catalog" 2>/dev/null || true
  else
    grep 'omlx_hf:' "$catalog" | sed 's/.*omlx_hf: //' | tr -d ' ' || true
  fi
}
