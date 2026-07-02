#!/usr/bin/env bash
# Shared helpers for local-inference scripts

set -euo pipefail

CONFIG_DIR="${HOME}/.config/local-inference"
LOG_DIR="${HOME}/Library/Logs/local-inference"
STATE_FILE="${CONFIG_DIR}/state.env"

if [[ -f "${CONFIG_DIR}/repo.env" ]]; then
  # shellcheck disable=SC1091
  source "${CONFIG_DIR}/repo.env"
fi

if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -z "${REPO_ROOT:-}" ]]; then
  _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ "$_script_dir" == *"/.config/local-inference/bin/lib" ]]; then
    REPO_ROOT="${LOCAL_INFERENCE_REPO:?Set LOCAL_INFERENCE_REPO in repo.env}"
  else
    REPO_ROOT="$(cd "${_script_dir}/../.." && pwd)"
  fi
elif [[ -n "${REPO_ROOT:-}" ]]; then
  : # preserve REPO_ROOT from Makefile/caller
else
  REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

export REPO_ROOT CONFIG_DIR LOG_DIR STATE_FILE

# launchd agents get a minimal PATH — include Homebrew for hf, ollama, jq, etc.
ensure_path() {
  export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
}
ensure_path

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

dir_size_kb() {
  local path="$1"
  [[ -e "$path" ]] || { echo 0; return; }
  du -sk "$path" 2>/dev/null | awk '{print $1}'
}

dir_size_gb() {
  local kb
  kb="$(dir_size_kb "$1")"
  awk -v k="$kb" 'BEGIN { printf "%.2f", k / 1024 / 1024 }'
}

is_size_complete() {
  local path="$1" expected_gb="$2"
  [[ -n "$expected_gb" && "$expected_gb" != "0" ]] || return 1
  local kb min_kb
  kb="$(dir_size_kb "$path")"
  min_kb="$(awk -v g="$expected_gb" 'BEGIN { printf "%d", g * 1024 * 1024 * 0.9 }')"
  [[ "$kb" -ge "$min_kb" ]]
}

ollama_has_model() {
  local model="$1"
  ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -qx "${model%%:*}" || \
    ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -qx "$model"
}

ensure_hf_cli() {
  local bin
  for bin in hf huggingface-cli; do
    if command_exists "$bin"; then
      command -v "$bin"
      return 0
    fi
  done
  if command_exists brew; then
    brew install hf 2>/dev/null || brew install huggingface-cli 2>/dev/null || true
    for bin in hf huggingface-cli; do
      if command_exists "$bin"; then
        command -v "$bin"
        return 0
      fi
    done
  fi
  return 1
}

clean_hf_locks() {
  find "${HOME}/models" -path '*/.cache/huggingface/*.lock' -delete 2>/dev/null || true
}
