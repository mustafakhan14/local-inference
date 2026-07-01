#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
mkdir -p "${REPO_ROOT}/.cursor/rules"
cp "${REPO_ROOT}/cursor/templates/local-privacy.mdc" "${REPO_ROOT}/.cursor/rules/local-privacy.mdc"
