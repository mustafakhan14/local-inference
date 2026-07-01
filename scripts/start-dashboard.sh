#!/usr/bin/env bash
# Legacy — Stack Hub runs in Docker. Use: make start
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
warn "start-dashboard.sh is deprecated. Stack Hub runs at http://127.0.0.1:3080/hub"
warn "Run: make start"
