#!/usr/bin/env bash
# Resumable targeted model downloads for hub / CLI
set -euo pipefail

_script_dir="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "${_script_dir}/lib/common.sh" ]]; then
  source "${_script_dir}/lib/common.sh"
else
  source "$(dirname "$0")/lib/common.sh"
fi

TARGET="${1:-all}"
LOG_FILE="${LOG_DIR}/pull-models.log"
PID_FILE="${CONFIG_DIR}/download.pid"
ACTIVE_FILE="${CONFIG_DIR}/download-active.json"

ensure_dirs
mkdir -p "${HOME}/models"

write_pid() {
  echo "$$" > "$PID_FILE"
  echo "{\"pid\":$$,\"target\":\"$1\",\"started\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$ACTIVE_FILE"
}

clear_pid() {
  rm -f "$PID_FILE" "$ACTIVE_FILE"
}

pull_ollama_primary() {
  local model="qwen3.5:35b-a3b-coding-nvfp4"
  if ollama_has_model "$model"; then
    log "Already have Ollama model: $model"
    return 0
  fi
  log "Pulling Ollama model: $model"
  ollama pull "$model"
}

pull_mlx_hf() {
  local hf_id="$1" expected_gb="$2" label="$3"
  local target="${HOME}/models/$(basename "$hf_id")"
  if is_size_complete "$target" "$expected_gb"; then
    log "MLX model complete: $label ($target)"
    return 0
  fi
  local hf_bin
  hf_bin="$(ensure_hf_cli)" || die "Install hf: brew install hf"
  clean_hf_locks
  mkdir -p "$target"
  log "Downloading MLX model: $label ($hf_id) — resumable"
  "$hf_bin" download "$hf_id" --local-dir "$target"
}

run_target() {
  case "$1" in
    primary-ollama)
      write_pid "primary-ollama"
      pull_ollama_primary
      ;;
    primary-mlx)
      write_pid "primary-mlx"
      pull_mlx_hf "mlx-community/Qwen3.5-35B-A3B-Instruct-4bit" 20 "Qwen 35B MLX"
      ;;
    fable-agent)
      write_pid "fable-agent"
      pull_mlx_hf "shuhulx/Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit" 2.5 "Fable5 MLX"
      ;;
    all)
      write_pid "all"
      pull_ollama_primary || true
      pull_mlx_hf "shuhulx/Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit" 2.5 "Fable5 MLX" || true
      pull_mlx_hf "mlx-community/Qwen3.5-35B-A3B-Instruct-4bit" 20 "Qwen 35B MLX" || true
      ;;
    *)
      die "Unknown target: $1 (use: primary-ollama|primary-mlx|fable-agent|all)"
      ;;
  esac
}

exec >> >(tee -a "$LOG_FILE") 2>&1
log "=== resume-download: $TARGET ==="

if [[ -f "$PID_FILE" ]]; then
  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    warn "Download already running (pid $old_pid)"
    exit 0
  fi
fi

trap clear_pid EXIT
run_target "$TARGET"
log "=== resume-download complete: $TARGET ==="
