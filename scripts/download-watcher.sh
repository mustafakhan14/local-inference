#!/usr/bin/env bash
# Polls download-request.json and runs resume-download.sh on the host
set -euo pipefail

BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${BIN_DIR}/lib/common.sh"

REQUEST_FILE="${CONFIG_DIR}/download-request.json"
SCRIPT="${BIN_DIR}/resume-download.sh"

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
