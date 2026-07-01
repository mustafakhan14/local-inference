#!/usr/bin/env python3
"""Stack Hub — live status UI for local inference stack."""
from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

PORT = int(os.environ.get("STACK_HUB_PORT", "8780"))
OMLX_HOST = os.environ.get("OMLX_HOST", "host.docker.internal")
OMLX_PORT = os.environ.get("OMLX_PORT", "8000")
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "host.docker.internal")
OLLAMA_PORT = os.environ.get("OLLAMA_PORT", "11434")
OMLX_KEY = os.environ.get("OMLX_API_KEY", "mkapikey")
MODELS_DIR = Path(os.environ.get("MODELS_DIR", "/models"))
CATALOG_PATH = Path(os.environ.get("CATALOG_PATH", "/app/catalog.yaml"))
HOME_CONFIG = os.environ.get("HOME_CONFIG", "/home-config")

BASE_URL = os.environ.get("PUBLIC_BASE_URL", "http://127.0.0.1:3080")


def curl_json(url: str, headers: dict | None = None, timeout: float = 3.0):
    req = urllib.request.Request(url, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
        return None


def dir_size_gb(path: Path) -> float:
    if not path.is_dir():
        return 0.0
    total = 0
    try:
        for root, _, files in os.walk(path):
            for f in files:
                try:
                    total += os.path.getsize(os.path.join(root, f))
                except OSError:
                    pass
    except OSError:
        return 0.0
    return round(total / (1024**3), 2)


def parse_catalog() -> list[dict]:
    models = []
    if not CATALOG_PATH.is_file():
        return models
    try:
        import yaml  # noqa: optional
    except ImportError:
        yaml = None
    if yaml:
        try:
            data = yaml.safe_load(CATALOG_PATH.read_text())
            for m in data.get("models", []):
                hf = m.get("omlx_hf")
                if hf:
                    models.append({
                        "id": m.get("id", ""),
                        "name": m.get("name", hf),
                        "hf_id": hf,
                        "dir_name": hf.split("/")[-1],
                        "size_gb": m.get("size_gb", 0),
                    })
            return models
        except Exception:
            pass
    # Fallback: line-based parse
    for line in CATALOG_PATH.read_text().splitlines():
        if "omlx_hf:" in line:
            hf = line.split("omlx_hf:", 1)[1].strip()
            models.append({"hf_id": hf, "dir_name": hf.split("/")[-1], "size_gb": 0})
    return models


def ollama_models() -> list[str]:
    data = curl_json(f"http://{OLLAMA_HOST}:{OLLAMA_PORT}/api/tags")
    if not data:
        return []
    return [m.get("name", "") for m in data.get("models", [])]


def disk_models() -> list[dict]:
    result = []
    catalog = {m["dir_name"]: m for m in parse_catalog()}
    if MODELS_DIR.is_dir():
        for p in sorted(MODELS_DIR.iterdir()):
            if not p.is_dir():
                continue
            size = dir_size_gb(p)
            meta = catalog.get(p.name, {})
            expected = meta.get("size_gb", 0)
            pct = min(100, int(size / expected * 100)) if expected else None
            result.append({
                "name": p.name,
                "size_gb": size,
                "expected_gb": expected,
                "progress_pct": pct,
                "complete": expected > 0 and size >= expected * 0.9,
            })
    return result


def stack_status() -> dict:
    omlx_base = f"http://{OMLX_HOST}:{OMLX_PORT}"
    omlx = curl_json(f"{omlx_base}/health")
    omlx_models = curl_json(
        f"{omlx_base}/v1/models",
        {"Authorization": f"Bearer {OMLX_KEY}"},
    )
    agents_base = Path(HOME_CONFIG) / "agents" if Path(HOME_CONFIG).is_dir() else Path("/agents")

    return {
        "hub": {"up": True, "url": f"{BASE_URL}/hub"},
        "omlx": {
            "up": omlx is not None,
            "health": omlx,
            "models": (omlx_models or {}).get("data", []),
            "admin": f"{BASE_URL}/omlx/admin",
            "direct_admin": f"http://127.0.0.1:{OMLX_PORT}/admin",
        },
        "ollama": {
            "up": curl_json(f"http://{OLLAMA_HOST}:{OLLAMA_PORT}/api/tags") is not None,
            "models": ollama_models(),
        },
        "open_webui": {"up": True, "url": BASE_URL},
        "disk_models": disk_models(),
        "agents": {
            "opencode": {
                "name": "OpenCode",
                "desc": "Terminal coding agent — multi-file edits, shell",
                "cmd": f"{HOME_CONFIG}/agents/opencode.sh",
                "omlx": "omlx launch opencode",
            },
            "openclaw": {
                "name": "OpenClaw",
                "desc": "Personal assistant — tasks, automation",
                "cmd": f"{HOME_CONFIG}/agents/openclaw.sh",
                "omlx": "omlx launch openclaw --tools-profile coding",
            },
            "hermes": {
                "name": "Hermes",
                "desc": "General agent CLI via local API",
                "cmd": f"{HOME_CONFIG}/agents/hermes.sh",
                "omlx": "omlx launch hermes",
            },
            "cursor": {
                "name": "Cursor Agent",
                "desc": "IDE coding — Settings → Override OpenAI Base URL",
                "base_url": f"http://127.0.0.1:{OMLX_PORT}/v1",
                "api_key": OMLX_KEY,
            },
        },
        "cursor": {
            "base_url": f"http://127.0.0.1:{OMLX_PORT}/v1",
            "api_key": OMLX_KEY,
            "primary_model": "qwen3.5:35b-a3b-coding-nvfp4",
            "fable_local": "Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit",
        },
        "downloads": {
            "resume_cmd": "make update-models",
            "hf_fable": "hf download shuhulx/Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit --local-dir ~/models/Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit --resume-download",
            "ollama_primary": "ollama pull qwen3.5:35b-a3b-coding-nvfp4",
        },
    }


HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta http-equiv="refresh" content="10"/>
  <title>Local AI Stack Hub</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, system-ui, sans-serif; background: #0d1117; color: #e6edf3; padding: 24px; line-height: 1.5; max-width: 1200px; margin: 0 auto; }
    h1 { font-size: 1.35rem; margin-bottom: 4px; }
    .sub { color: #8b949e; font-size: 0.85rem; margin-bottom: 20px; }
    .nav { margin-bottom: 16px; }
    .nav a { margin-right: 16px; color: #58a6ff; text-decoration: none; font-size: 0.9rem; }
    .nav a:hover { text-decoration: underline; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px; }
    .card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 14px; }
    .card h2 { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; color: #8b949e; margin-bottom: 8px; }
    .ok { color: #3fb950; }
    .bad { color: #f85149; }
    .warn { color: #d29922; }
    ul { list-style: none; font-size: 0.85rem; }
    li { padding: 3px 0; }
    a { color: #58a6ff; text-decoration: none; }
    a:hover { text-decoration: underline; }
    code { background: #21262d; padding: 1px 5px; border-radius: 4px; font-size: 0.78rem; word-break: break-all; }
    .flow { margin-top: 16px; padding: 14px; background: #161b22; border: 1px solid #30363d; border-radius: 8px; font-size: 0.8rem; color: #8b949e; }
    .flow strong { color: #e6edf3; }
    .agent-card { border-left: 3px solid #388bfd; padding-left: 10px; margin-bottom: 10px; }
    .agent-card h3 { font-size: 0.9rem; margin-bottom: 2px; }
    .agent-card p { color: #8b949e; font-size: 0.8rem; }
    .bar { background: #21262d; border-radius: 4px; height: 6px; margin-top: 4px; overflow: hidden; }
    .bar-fill { background: #388bfd; height: 100%; }
  </style>
</head>
<body>
  <div class="nav">
    <a href="/">Chat (Open WebUI)</a>
    <a href="/hub">Stack Hub</a>
    <a href="/omlx/admin">oMLX Admin</a>
  </div>
  <h1>Local AI Stack Hub</h1>
  <p class="sub">Auto-refreshes every 10s · API key <code>mkapikey</code></p>
  <div class="grid" id="grid"></div>
  <div class="flow" id="flow"></div>
  <script>
    const s = __STATUS__;
    const dot = (ok) => ok ? '<span class="ok">●</span>' : '<span class="bad">○</span>';
    const agentsHtml = Object.values(s.agents).map(a => `
      <div class="agent-card">
        <h3>${a.name}</h3>
        <p>${a.desc || ''}</p>
        ${a.cmd ? `<li><code>${a.cmd}</code></li>` : ''}
        ${a.omlx ? `<li><code>${a.omlx}</code></li>` : ''}
        ${a.base_url ? `<li>URL: <code>${a.base_url}</code> key <code>${a.api_key}</code></li>` : ''}
      </div>`).join('');
    const diskHtml = s.disk_models.length ? s.disk_models.map(m => {
      const bar = m.progress_pct != null ? `<div class="bar"><div class="bar-fill" style="width:${m.progress_pct}%"></div></div>` : '';
      const status = m.complete ? '<span class="ok">complete</span>' : (m.progress_pct != null ? `<span class="warn">${m.progress_pct}%</span>` : '');
      return `<li><code>${m.name}</code> ${m.size_gb}GB ${status}${bar}</li>`;
    }).join('') : '<li class="warn">No MLX models on disk yet — run make update-models</li>';
    document.getElementById('grid').innerHTML = `
      <div class="card"><h2>Services</h2><ul>
        <li>${dot(s.omlx.up)} oMLX <a href="${s.omlx.admin}">admin</a></li>
        <li>${dot(s.ollama.up)} Ollama :11434</li>
        <li>${dot(s.open_webui.up)} <a href="${s.open_webui.url}">Open WebUI</a></li>
        <li>${dot(s.hub.up)} Stack Hub</li>
        <li>Loaded: ${(s.omlx.health?.engine_pool?.loaded_count ?? 0)} MLX model(s)</li>
      </ul></div>
      <div class="card"><h2>Ollama models</h2><ul>
        ${s.ollama.models.map(m => `<li><code>${m}</code></li>`).join('') || '<li class="warn">none yet — ollama pull qwen3.5:35b-a3b-coding-nvfp4</li>'}
      </ul></div>
      <div class="card"><h2>MLX models (~/models)</h2><ul>${diskHtml}</ul>
        <p style="margin-top:8px;font-size:0.75rem;color:#8b949e">Resume: <code>${s.downloads.resume_cmd}</code></p>
      </div>
      <div class="card"><h2>Agents</h2>${agentsHtml}
        <p style="margin-top:8px"><a href="${s.omlx.admin}">oMLX Applications tab</a></p>
      </div>
      <div class="card"><h2>Cursor config</h2><ul>
        <li>Base URL: <code>${s.cursor.base_url}</code></li>
        <li>API key: <code>${s.cursor.api_key}</code></li>
        <li>Model: <code>${s.cursor.primary_model}</code></li>
        <li>Fable-local: <code>${s.cursor.fable_local}</code></li>
      </ul></div>
      <div class="card"><h2>Quick links</h2><ul>
        <li><a href="/">Chat</a></li>
        <li><a href="/omlx/admin">Load MLX models</a></li>
        <li><a href="/omlx/admin/chat">oMLX Chat</a></li>
        <li>Guide: ~/.config/local-inference/cursor-settings.md</li>
      </ul></div>
    `;
    document.getElementById('flow').innerHTML = `
      <strong>Data flow:</strong> Cursor / OpenCode / OpenClaw / Hermes → oMLX :8000 → MLX models in ~/models
      · Open WebUI → oMLX + Ollama · RAG via Ollama embeddings · One bookmark: <a href="/hub">/hub</a>
    `;
  </script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        path = self.path.split("?")[0]
        if path in ("/", "/index.html", "/hub", "/hub/"):
            status = stack_status()
            body = HTML.replace("__STATUS__", json.dumps(status))
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(body.encode())
        elif path in ("/api/status", "/hub/api/status"):
            body = json.dumps(stack_status(), indent=2)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body.encode())
        else:
            self.send_response(404)
            self.end_headers()


def main():
    print(f"Stack Hub listening on :{PORT}")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
