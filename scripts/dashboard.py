#!/usr/bin/env python3
"""Local AI Stack dashboard — dev-only. Production hub: http://127.0.0.1:3080/hub"""
from __future__ import annotations

import json
import os
import subprocess
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

PORT = int(os.environ.get("DASHBOARD_PORT", "8765"))
OMLX_KEY = os.environ.get("OMLX_API_KEY", "mkapikey")
HOME = Path.home()


def curl_json(url: str, headers: dict | None = None, timeout: float = 2.0):
    req = urllib.request.Request(url, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return None


def check_port(port: int) -> bool:
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=1.5):
            return True
    except Exception:
        return False


def ollama_models() -> list[str]:
    data = curl_json("http://127.0.0.1:11434/api/tags")
    if not data:
        return []
    return [m.get("name", "") for m in data.get("models", [])]


def stack_status() -> dict:
    omlx = curl_json("http://127.0.0.1:8000/health")
    omlx_models = curl_json(
        "http://127.0.0.1:8000/v1/models",
        {"Authorization": f"Bearer {OMLX_KEY}"},
    )
    models_on_disk = []
    for d in [HOME / "models", HOME / ".omlx" / "models"]:
        if d.is_dir():
            models_on_disk.extend([p.name for p in d.iterdir() if p.is_dir()])

    return {
        "omlx": {
            "up": omlx is not None,
            "health": omlx,
            "models": (omlx_models or {}).get("data", []),
            "admin": "http://127.0.0.1:8000/admin",
        },
        "ollama": {
            "up": curl_json("http://127.0.0.1:11434/api/tags") is not None,
            "models": ollama_models(),
        },
        "open_webui": {"up": check_port(3080), "url": "http://127.0.0.1:3080"},
        "dashboard": {"url": f"http://127.0.0.1:{PORT}"},
        "disk_models": sorted(set(models_on_disk)),
        "agents": {
            "opencode": str(HOME / ".config/local-inference/agents/opencode.sh"),
            "openclaw": str(HOME / ".config/local-inference/agents/openclaw.sh"),
            "hermes": str(HOME / ".config/local-inference/agents/hermes.sh"),
            "claude_local": str(HOME / ".config/local-inference/claude-local.sh"),
        },
        "cursor": {
            "base_url": "http://127.0.0.1:8000/v1",
            "api_key": OMLX_KEY,
            "primary_model": "qwen3.5:35b-a3b-coding-nvfp4",
            "fable_local": "Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit",
        },
    }


HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta http-equiv="refresh" content="10"/>
  <title>Local AI Stack</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, system-ui, sans-serif; background: #0d1117; color: #e6edf3; padding: 24px; line-height: 1.5; }
    h1 { font-size: 1.25rem; margin-bottom: 4px; }
    .sub { color: #8b949e; font-size: 0.85rem; margin-bottom: 20px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px; }
    .card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 14px; }
    .card h2 { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; color: #8b949e; margin-bottom: 8px; }
    .ok { color: #3fb950; }
    .bad { color: #f85149; }
    .warn { color: #d29922; }
    ul { list-style: none; font-size: 0.85rem; }
    li { padding: 2px 0; }
    a { color: #58a6ff; text-decoration: none; }
    a:hover { text-decoration: underline; }
    code { background: #21262d; padding: 1px 5px; border-radius: 4px; font-size: 0.8rem; }
    .flow { margin-top: 16px; padding: 14px; background: #161b22; border: 1px solid #30363d; border-radius: 8px; font-size: 0.8rem; color: #8b949e; }
    .flow strong { color: #e6edf3; }
  </style>
</head>
<body>
  <h1>Local AI Stack</h1>
  <p class="sub">Auto-refreshes every 10s · M4 Pro 48GB · API key <code>mkapikey</code></p>
  <div class="grid" id="grid"></div>
  <div class="flow" id="flow"></div>
  <script>
    const s = __STATUS__;
    const dot = (ok) => ok ? '<span class="ok">●</span>' : '<span class="bad">○</span>';
    document.getElementById('grid').innerHTML = `
      <div class="card"><h2>Inference</h2><ul>
        <li>${dot(s.omlx.up)} oMLX <a href="${s.omlx.admin}">admin</a> :8000</li>
        <li>${dot(s.ollama.up)} Ollama :11434</li>
        <li>Loaded: ${(s.omlx.health?.engine_pool?.loaded_count ?? 0)} model(s)</li>
      </ul></div>
      <div class="card"><h2>UI</h2><ul>
        <li>${dot(s.open_webui.up)} <a href="${s.open_webui.url}">Open WebUI</a> :3001</li>
        <li><a href="http://127.0.0.1:8000/admin/chat">oMLX Chat</a></li>
        <li>AnythingLLM (desktop app)</li>
      </ul></div>
      <div class="card"><h2>Ollama models</h2><ul>
        ${s.ollama.models.map(m => `<li><code>${m}</code></li>`).join('') || '<li class="warn">none yet</li>'}
      </ul></div>
      <div class="card"><h2>Agents — when to use</h2><ul>
        <li><strong>Cursor Agent</strong> — IDE coding (this chat)</li>
        <li><strong>OpenCode</strong> — terminal repo agent</li>
        <li><strong>OpenClaw</strong> — personal assistant</li>
        <li><strong>Hermes / Claude local</strong> — CLI agents</li>
      </ul></div>
      <div class="card"><h2>Cursor config</h2><ul>
        <li>Base URL: <code>${s.cursor.base_url}</code></li>
        <li>API key: <code>${s.cursor.api_key}</code></li>
        <li>Model: <code>${s.cursor.primary_model}</code></li>
        <li>Fable-local: <code>${s.cursor.fable_local}</code></li>
      </ul></div>
      <div class="card"><h2>Disk models (~/models)</h2><ul>
        ${s.disk_models.slice(0,8).map(m => `<li><code>${m}</code></li>`).join('') || '<li class="warn">download via oMLX admin</li>'}
      </ul></div>
    `;
    document.getElementById('flow').innerHTML = `
      <strong>Data flow:</strong> Cursor / OpenCode / OpenClaw → oMLX :8000 (agents + cache) → MLX models in ~/models
      · Open WebUI / AnythingLLM → same API · Ollama :11434 for quick pulls &amp; GGUF fallback
    `;
  </script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            status = stack_status()
            body = HTML.replace("__STATUS__", json.dumps(status))
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(body.encode())
        elif self.path == "/api/status":
            body = json.dumps(stack_status(), indent=2)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body.encode())
        else:
            self.send_response(404)
            self.end_headers()


def main():
    print(f"Dashboard: http://127.0.0.1:{PORT}")
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
