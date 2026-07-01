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

while IFS= read -r model; do
  [[ -z "$model" || "$model" == "null" ]] && continue
  if [[ "$model" == "qwen2.5vl:7b" && "$PULL_OPTIONAL" != "1" ]]; then
    log "Skipping optional model: $model"
    continue
  fi
  if ollama_has_model "$model"; then
    log "Already have: $model"
  else
    log "Pulling $model (this may take a while)..."
    ollama pull "$model"
  fi
done < <(catalog_ollama_models)

log "Ollama models ready:"
ollama list

clean_hf_locks

log ""
log "MLX models via resume-download.sh..."
bash "${REPO_ROOT}/scripts/resume-download.sh" all

log "Model pull complete. Log: $LOG_FILE"
