#!/usr/bin/env bash
# Polls download-request.json and runs resume-download.sh on the host
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

REQUEST_FILE="${CONFIG_DIR}/download-request.json"
SCRIPT="${REPO_ROOT}/scripts/resume-download.sh"

ensure_dirs
log "Download watcher started (polls ${REQUEST_FILE})"

while true; do
  if [[ -f "$REQUEST_FILE" ]]; then
    target="$(jq -r '.id // "all"' "$REQUEST_FILE" 2>/dev/null || echo all)"
    rm -f "$REQUEST_FILE"
    log "Download request: $target"
    bash "$SCRIPT" "$target" &
  fi
  sleep 2
done
