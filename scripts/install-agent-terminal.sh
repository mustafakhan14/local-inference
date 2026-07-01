#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

log "Installing browser terminal (ttyd)..."

if ! command_exists ttyd; then
  brew install ttyd
fi

TTYD_BIN="$(command -v ttyd)"
DST="${HOME}/Library/LaunchAgents/com.local-inference.terminal.plist"

cat > "$DST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local-inference.terminal</string>
    <key>ProgramArguments</key>
    <array>
        <string>${TTYD_BIN}</string>
        <string>-p</string>
        <string>7681</string>
        <string>-i</string>
        <string>127.0.0.1</string>
        <string>-W</string>
        <string>zsh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/local-inference/terminal.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/local-inference/terminal.err.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/com.local-inference.terminal" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$DST"
launchctl kickstart -k "gui/$(id -u)/com.local-inference.terminal" 2>/dev/null || true

if curl -sf http://127.0.0.1:7681 >/dev/null 2>&1; then
  log "ttyd running — proxied at http://127.0.0.1:3080/hub/terminal/"
else
  warn "ttyd installed; may need a moment — check ~/Library/Logs/local-inference/terminal.log"
fi
