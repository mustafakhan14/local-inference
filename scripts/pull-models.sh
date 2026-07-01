#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

PULL_OPTIONAL="${PULL_OPTIONAL:-1}"
LOG_FILE="${LOG_DIR}/pull-models.log"

ensure_dirs
exec > >(tee -a "$LOG_FILE") 2>&1

log "Pulling Ollama models from catalog..."

if ! command_exists ollama; then
  die "Ollama not installed. Run install-ollama.sh first."
fi

load_ollama_env
wait_for_url "http://127.0.0.1:11434/api/tags" 30 2 || die "Ollama not running"

catalog="${REPO_ROOT}/models/catalog.yaml"

while IFS= read -r model; do
  [[ -z "$model" || "$model" == "null" ]] && continue

  if [[ "$model" == "qwen2.5vl:7b" && "$PULL_OPTIONAL" != "1" ]]; then
    log "Skipping optional model: $model"
    continue
  fi

  if ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -qx "${model%%:*}" || \
     ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -qx "$model"; then
    log "Already have: $model"
  else
    log "Pulling $model (this may take a while)..."
    ollama pull "$model"
  fi
done < <(catalog_ollama_models)

log "Ollama models ready:"
ollama list

# Clean stale HuggingFace lock files
log ""
log "Cleaning stale HF lock files..."
find "${HOME}/models" -path '*/.cache/huggingface/*.lock' -delete 2>/dev/null || true

# Ensure hf CLI
if command_exists hf; then
  HF_CMD=hf
elif command_exists huggingface-cli; then
  HF_CMD=huggingface-cli
else
  log "Installing huggingface-cli via brew..."
  brew install hf 2>/dev/null || brew install huggingface-cli 2>/dev/null || true
  if command_exists hf; then
    HF_CMD=hf
  elif command_exists huggingface-cli; then
    HF_CMD=huggingface-cli
  else
    HF_CMD=""
  fi
fi

log ""
log "oMLX MLX models (~/models):"
while IFS= read -r hf_id; do
  [[ -z "$hf_id" ]] && continue
  log "  - $hf_id"
done < <(catalog_omlx_hf_models)

if [[ -n "$HF_CMD" ]]; then
  while IFS= read -r hf_id; do
    [[ -z "$hf_id" ]] && continue
    target="${HOME}/models/$(basename "$hf_id")"
    if [[ -d "$target" ]] && find "$target" -name '*.safetensors' -o -name '*.json' 2>/dev/null | grep -q .; then
      log "MLX model present: $target"
    else
      mkdir -p "$target"
      log "Downloading MLX model: $hf_id (resumable)..."
      $HF_CMD download "$hf_id" --local-dir "$target" --resume-download || \
        warn "HF download failed for $hf_id — retry: $HF_CMD download $hf_id --local-dir $target --resume-download"
    fi
  done < <(catalog_omlx_hf_models)
else
  warn "Install hf for MLX downloads: brew install hf"
  warn "Or download models at http://127.0.0.1:3080/omlx/admin"
fi

log "Model pull complete. Log: $LOG_FILE"
