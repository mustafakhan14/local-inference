#!/usr/bin/env bash
# Install download scripts outside ~/Documents (avoids macOS TCC blocking launchd)
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

BIN_DIR="${CONFIG_DIR}/bin"
LIB_DIR="${BIN_DIR}/lib"

ensure_dirs
mkdir -p "$BIN_DIR" "$LIB_DIR"

echo "LOCAL_INFERENCE_REPO=${REPO_ROOT}" > "${CONFIG_DIR}/repo.env"

cp "${REPO_ROOT}/scripts/lib/common.sh" "${LIB_DIR}/common.sh"
cp "${REPO_ROOT}/scripts/resume-download.sh" "${BIN_DIR}/resume-download.sh"
cp "${REPO_ROOT}/scripts/download-watcher.sh" "${BIN_DIR}/download-watcher.sh"
chmod +x "${BIN_DIR}/resume-download.sh" "${BIN_DIR}/download-watcher.sh"

DST="${HOME}/Library/LaunchAgents/com.local-inference.download-watcher.plist"
cat > "$DST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local-inference.download-watcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${BIN_DIR}/download-watcher.sh</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/local-inference/download-watcher.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/local-inference/download-watcher.err.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/com.local-inference.download-watcher" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$DST"
launchctl kickstart -k "gui/$(id -u)/com.local-inference.download-watcher" 2>/dev/null || true

log "Host scripts installed: ${BIN_DIR}/"
log "Download watcher reloaded (outside Documents — TCC safe)"
