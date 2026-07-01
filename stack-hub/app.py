#!/usr/bin/env python3
"""Stack Hub — status, downloads, agents, terminal launcher."""
from __future__ import annotations

import json
import os
import subprocess
import time
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
HOME_CONFIG = Path(os.environ.get("HOME_CONFIG", "/home-config"))
LOG_DIR = Path(os.environ.get("LOG_DIR", "/logs"))
BASE_URL = os.environ.get("PUBLIC_BASE_URL", "http://127.0.0.1:3080")

DOWNLOAD_JOBS = [
    {
        "id": "primary-ollama",
        "name": "Qwen 35B (Ollama)",
        "backend": "ollama",
        "ollama": "qwen3.5:35b-a3b-coding-nvfp4",
        "expected_gb": 20,
    },
    {
        "id": "primary-mlx",
        "name": "Qwen 35B (MLX)",
        "backend": "mlx",
        "hf_id": "mlx-community/Qwen3.5-35B-A3B-Instruct-4bit",
        "dir_name": "Qwen3.5-35B-A3B-Instruct-4bit",
        "expected_gb": 20,
    },
    {
        "id": "fable-agent",
        "name": "Fable5 MLX (4B)",
        "backend": "mlx",
        "hf_id": "shuhulx/Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit",
        "dir_name": "Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit",
        "expected_gb": 2.5,
    },
]

AGENT_CMDS = {
    "hermes": f"{HOME_CONFIG}/agents/hermes.sh",
    "openclaw": f"{HOME_CONFIG}/agents/openclaw.sh",
    "opencode": f"{HOME_CONFIG}/agents/opencode.sh",
}


def curl_json(url: str, headers: dict | None = None, timeout: float = 3.0):
    req = urllib.request.Request(url, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
        return None


def dir_size_gb(path: Path) -> float:
    if not path.exists():
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


def log_tail(n: int = 8) -> list[str]:
    log_file = LOG_DIR / "pull-models.log"
    if not log_file.is_file():
        return []
    try:
        lines = log_file.read_text(errors="replace").splitlines()
        tail = lines[-n:]
        return [line[:200] for line in tail]
    except OSError:
        return []


def download_pid_alive() -> tuple[bool, str | None]:
    pid_file = HOME_CONFIG / "download.pid"
    active_file = HOME_CONFIG / "download-active.json"
    if not pid_file.is_file():
        return False, None
    try:
        pid = int(pid_file.read_text().strip())
        os.kill(pid, 0)
        active = None
        if active_file.is_file():
            active = json.loads(active_file.read_text()).get("target")
        return True, active
    except (OSError, ValueError, json.JSONDecodeError):
        return False, None


def ollama_models() -> list[str]:
    data = curl_json(f"http://{OLLAMA_HOST}:{OLLAMA_PORT}/api/tags")
    if not data:
        return []
    return [m.get("name", "") for m in data.get("models", [])]


def job_status(job: dict) -> dict:
    expected = job["expected_gb"]
    downloading, active_target = download_pid_alive()
    is_active = downloading and active_target in (job["id"], "all")

    if job["backend"] == "ollama":
        model = job["ollama"]
        names = ollama_models()
        complete = any(model in n or n.startswith(model.split(":")[0]) for n in names)
        size_gb = expected if complete else 0.0
        progress = 100 if complete else 0
        status = "complete" if complete else ("downloading" if is_active else "missing")
        return {**job, "size_gb": size_gb, "progress_pct": progress, "status": status}

    dir_path = MODELS_DIR / job["dir_name"]
    size_gb = dir_size_gb(dir_path)
    progress = min(100, int(size_gb / expected * 100)) if expected else 0
    complete = size_gb >= expected * 0.9
    if complete:
        status = "complete"
    elif is_active:
        status = "downloading"
    elif size_gb > 0.01:
        status = "paused"
    else:
        status = "missing"
    return {**job, "size_gb": size_gb, "progress_pct": progress, "status": status}


def downloads_status() -> dict:
    jobs = [job_status(j) for j in DOWNLOAD_JOBS]
    downloading, active = download_pid_alive()
    return {
        "jobs": jobs,
        "active_job": active if downloading else None,
        "log_tail": log_tail(10),
        "log_path": str(LOG_DIR / "pull-models.log"),
    }


def stack_status() -> dict:
    omlx_base = f"http://{OMLX_HOST}:{OMLX_PORT}"
    omlx = curl_json(f"{omlx_base}/health")
    omlx_models = curl_json(
        f"{omlx_base}/v1/models",
        {"Authorization": f"Bearer {OMLX_KEY}"},
    )
    dl = downloads_status()
    return {
        "hub": {"up": True, "url": f"{BASE_URL}/hub"},
        "omlx": {
            "up": omlx is not None,
            "health": omlx,
            "models": (omlx_models or {}).get("data", []),
            "admin": f"{BASE_URL}/omlx/admin",
        },
        "ollama": {
            "up": curl_json(f"http://{OLLAMA_HOST}:{OLLAMA_PORT}/api/tags") is not None,
            "models": ollama_models(),
        },
        "open_webui": {"up": True, "url": BASE_URL},
        "downloads": dl,
        "agents": {
            "hermes": {"name": "Hermes", "cmd": AGENT_CMDS["hermes"], "chat": f"{BASE_URL}/hub/agents/hermes"},
            "openclaw": {"name": "OpenClaw", "cmd": AGENT_CMDS["openclaw"], "chat": f"{BASE_URL}/hub/agents/openclaw"},
            "opencode": {"name": "OpenCode", "cmd": AGENT_CMDS["opencode"]},
            "terminal": f"{BASE_URL}/hub/terminal/",
        },
        "cursor": {
            "base_url": f"http://127.0.0.1:{OMLX_PORT}/v1",
            "api_key": OMLX_KEY,
            "primary_model": "qwen3.5:35b-a3b-coding-nvfp4",
        },
    }


def queue_download(job_id: str) -> bool:
    req_file = HOME_CONFIG / "download-request.json"
    try:
        HOME_CONFIG.mkdir(parents=True, exist_ok=True)
        req_file.write_text(json.dumps({"id": job_id, "ts": time.time()}))
        return True
    except OSError:
        return False


NAV = """
<div class="nav">
  <a href="/">Chat</a>
  <a href="/hub/">Hub</a>
  <a href="/hub/#downloads">Downloads</a>
  <a href="/hub/#terminal">Terminal</a>
  <a href="/hub/agents/hermes">Hermes Chat</a>
  <a href="/hub/agents/openclaw">OpenClaw Chat</a>
  <a href="/omlx/admin">oMLX Admin</a>
</div>
"""

STYLES = """
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,system-ui,sans-serif;background:#0d1117;color:#e6edf3;padding:20px;line-height:1.5;max-width:1100px;margin:0 auto}
h1{font-size:1.3rem;margin-bottom:4px}
.sub{color:#8b949e;font-size:.85rem;margin-bottom:16px}
.nav{margin-bottom:16px}.nav a{margin-right:14px;color:#58a6ff;text-decoration:none;font-size:.88rem}
.nav a:hover{text-decoration:underline}
.tabs{display:flex;gap:8px;margin-bottom:16px;flex-wrap:wrap}
.tab{padding:6px 14px;border-radius:6px;border:1px solid #30363d;background:#161b22;color:#e6edf3;cursor:pointer;font-size:.85rem}
.tab.active{background:#388bfd;border-color:#388bfd}
.panel{display:none}.panel.active{display:block}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px}
.card{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:14px}
.card h2{font-size:.72rem;text-transform:uppercase;letter-spacing:.05em;color:#8b949e;margin-bottom:8px}
.ok{color:#3fb950}.bad{color:#f85149}.warn{color:#d29922}
ul{list-style:none;font-size:.85rem}li{padding:2px 0}
code{background:#21262d;padding:1px 5px;border-radius:4px;font-size:.78rem;word-break:break-all}
.btn{display:inline-block;margin-top:8px;padding:6px 12px;background:#238636;border:1px solid #2ea043;border-radius:6px;color:#fff;font-size:.8rem;cursor:pointer}
.btn:hover{background:#2ea043}.btn.secondary{background:#21262d;border-color:#30363d}
.dl-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:14px;margin-bottom:16px}
.dl-card{background:#161b22;border:2px solid #30363d;border-radius:10px;padding:16px}
.dl-card.downloading{border-color:#388bfd}
.dl-card.complete{border-color:#3fb950}
.dl-card h3{font-size:.95rem;margin-bottom:6px}
.badge{font-size:.7rem;padding:2px 8px;border-radius:10px;background:#21262d;display:inline-block;margin-bottom:8px}
.badge.downloading{background:#1f3d5c;color:#58a6ff}
.badge.complete{background:#1a3d2a;color:#3fb950}
.badge.paused,.badge.missing{background:#3d2e1a;color:#d29922}
.bar{background:#21262d;border-radius:6px;height:10px;margin:8px 0;overflow:hidden}
.bar-fill{background:linear-gradient(90deg,#388bfd,#58a6ff);height:100%;transition:width .5s}
.logbox{background:#0d1117;border:1px solid #30363d;border-radius:6px;padding:10px;font-family:ui-monospace,monospace;font-size:.72rem;color:#8b949e;max-height:120px;overflow:auto;margin-top:12px}
iframe.term{width:100%;height:480px;border:1px solid #30363d;border-radius:8px;background:#000}
.agent-btns{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:10px}
.chat-wrap{display:flex;flex-direction:column;height:calc(100vh - 120px)}
.chat-log{flex:1;overflow:auto;border:1px solid #30363d;border-radius:8px;padding:12px;margin-bottom:10px;background:#161b22}
.msg{margin-bottom:10px}.msg.user{color:#58a6ff}.msg.assistant{color:#e6edf3}
.chat-input{display:flex;gap:8px}textarea{flex:1;background:#161b22;border:1px solid #30363d;border-radius:6px;color:#e6edf3;padding:8px;resize:vertical;min-height:60px}
"""

HUB_HTML = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"/><title>Stack Hub</title>
<style>{STYLES}</style></head><body>
{NAV}
<h1>Local AI Stack Hub</h1>
<p class="sub">API key <code>mkapikey</code> · live updates</p>
<div class="tabs">
  <button class="tab active" data-tab="downloads">Downloads</button>
  <button class="tab" data-tab="status">Status</button>
  <button class="tab" data-tab="agents">Agents</button>
  <button class="tab" data-tab="terminal">Terminal</button>
</div>
<div id="downloads" class="panel active">
  <div class="dl-grid" id="dl-grid"></div>
  <div class="logbox" id="dl-log"></div>
</div>
<div id="status" class="panel"><div class="grid" id="status-grid"></div></div>
<div id="agents" class="panel">
  <div class="card">
    <h2>Quick chat (browser)</h2>
    <ul><li><a href="/hub/agents/hermes">Hermes Chat</a> — Anthropic-style agent</li>
    <li><a href="/hub/agents/openclaw">OpenClaw Chat</a> — task assistant (simplified)</li></ul>
    <p class="sub" style="margin-top:10px">Full agent sessions (tools, shell, files) → Terminal tab</p>
  </div>
  <div class="grid" id="agents-grid" style="margin-top:12px"></div>
</div>
<div id="terminal" class="panel">
  <div class="agent-btns">
    <button class="btn secondary" onclick="copyCmd('hermes')">Copy Hermes cmd</button>
    <button class="btn secondary" onclick="copyCmd('openclaw')">Copy OpenClaw cmd</button>
    <button class="btn secondary" onclick="copyCmd('opencode')">Copy OpenCode cmd</button>
  </div>
  <p class="sub">Paste a command into the terminal below, or run from your Mac terminal.</p>
  <iframe class="term" src="/hub/terminal/" title="Agent terminal"></iframe>
</div>
<script>
const CMDS = {json.dumps(AGENT_CMDS)};
function copyCmd(k) {{ navigator.clipboard.writeText(CMDS[k]); alert('Copied: ' + CMDS[k]); }}
document.querySelectorAll('.tab').forEach(t => t.onclick = () => {{
  document.querySelectorAll('.tab,.panel').forEach(e => e.classList.remove('active'));
  t.classList.add('active');
  document.getElementById(t.dataset.tab).classList.add('active');
}});
if (location.hash === '#terminal') document.querySelector('[data-tab=terminal]').click();
if (location.hash === '#downloads') document.querySelector('[data-tab=downloads]').click();

async function resume(id) {{
  await fetch('/hub/api/downloads/resume', {{method:'POST', headers:{{'Content-Type':'application/json'}}, body:JSON.stringify({{id}})}});
  pollDownloads();
}}
function renderDownloads(d) {{
  document.getElementById('dl-grid').innerHTML = d.jobs.map(j => `
    <div class="dl-card ${{j.status}}">
      <h3>${{j.name}}</h3>
      <span class="badge ${{j.status}}">${{j.status}}</span>
      <div>${{j.size_gb}} / ${{j.expected_gb}} GB (${{j.progress_pct}}%)</div>
      <div class="bar"><div class="bar-fill" style="width:${{j.progress_pct}}%"></div></div>
      ${{j.status !== 'complete' ? `<button class="btn" onclick="resume('${{j.id}}')">Resume</button>` : '<span class="ok">Ready</span>'}}
    </div>`).join('');
  document.getElementById('dl-log').innerHTML = (d.log_tail||[]).join('<br>') || 'No log yet';
}}
async function pollDownloads() {{
  const r = await fetch('/hub/api/downloads'); renderDownloads(await r.json());
}}
async function pollStatus() {{
  const s = await fetch('/hub/api/status').then(r=>r.json());
  const dot = ok => ok ? '<span class="ok">●</span>' : '<span class="bad">○</span>';
  document.getElementById('status-grid').innerHTML = `
    <div class="card"><h2>Services</h2><ul>
      <li>${{dot(s.omlx.up)}} oMLX <a href="${{s.omlx.admin}}">admin</a></li>
      <li>${{dot(s.ollama.up)}} Ollama</li>
      <li>${{dot(s.open_webui.up)}} <a href="${{s.open_webui.url}}">Open WebUI</a></li>
      <li>MLX loaded: ${{(s.omlx.health?.engine_pool?.loaded_count ?? 0)}}</li>
    </ul></div>
    <div class="card"><h2>Ollama</h2><ul>${{s.ollama.models.map(m=>`<li><code>${{m}}</code></li>`).join('')||'<li class=warn>none</li>'}}</ul></div>
    <div class="card"><h2>Cursor</h2><ul>
      <li><code>${{s.cursor.base_url}}</code></li>
      <li>Model: <code>${{s.cursor.primary_model}}</code></li>
    </ul></div>`;
  document.getElementById('agents-grid').innerHTML = Object.entries(s.agents).filter(([k])=>k!=='terminal').map(([k,a])=>`
    <div class="card"><h2>${{a.name||k}}</h2>
      ${{a.chat?`<li><a href="${{a.chat}}">Open chat</a></li>`:''}}
      <li><code>${{a.cmd}}</code></li></div>`).join('');
}}
pollDownloads(); pollStatus();
setInterval(pollDownloads, 3000);
setInterval(pollStatus, 10000);
</script></body></html>"""


def agent_chat_html(agent: str, title: str, subtitle: str, api_mode: str) -> str:
    system = (
        "You are Hermes, a helpful local AI agent. Be concise and actionable."
        if agent == "hermes"
        else "You are a personal assistant (OpenClaw-style). Help with tasks, planning, and automation. "
        "Note: this is a simplified chat — for full OpenClaw with tools, use the Terminal."
    )
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"/><title>{title}</title>
<style>{STYLES}</style></head><body>
{NAV}
<h1>{title}</h1>
<p class="sub">{subtitle}</p>
<div class="chat-wrap">
  <div class="chat-log" id="log"></div>
  <div class="chat-input">
    <textarea id="input" placeholder="Message..."></textarea>
    <button class="btn" id="send">Send</button>
  </div>
</div>
<script>
const API_MODE = {json.dumps(api_mode)};
const SYSTEM = {json.dumps(system)};
const log = document.getElementById('log');
const input = document.getElementById('input');
function add(role, text) {{
  const d = document.createElement('div');
  d.className = 'msg ' + role;
  d.textContent = (role === 'user' ? 'You: ' : 'Agent: ') + text;
  log.appendChild(d); log.scrollTop = log.scrollHeight;
}}
async function send() {{
  const text = input.value.trim(); if (!text) return;
  input.value = ''; add('user', text);
  try {{
    if (API_MODE === 'anthropic') {{
      const r = await fetch('/omlx/v1/messages', {{
        method:'POST',
        headers:{{'Content-Type':'application/json','Authorization':'Bearer mkapikey','anthropic-version':'2023-06-01'}},
        body: JSON.stringify({{
          model: 'qwen3.5:35b-a3b-coding-nvfp4',
          max_tokens: 1024,
          system: SYSTEM,
          messages: [{{role:'user', content: text}}]
        }})
      }});
      const j = await r.json();
      const reply = (j.content && j.content[0] && j.content[0].text) || j.error?.message || JSON.stringify(j);
      add('assistant', reply);
    }} else {{
      const r = await fetch('/omlx/v1/chat/completions', {{
        method:'POST',
        headers:{{'Content-Type':'application/json','Authorization':'Bearer mkapikey'}},
        body: JSON.stringify({{
          model: 'qwen2.5-coder:14b',
          max_tokens: 1024,
          messages: [
            {{role:'system', content: SYSTEM}},
            {{role:'user', content: text}}
          ]
        }})
      }});
      const j = await r.json();
      add('assistant', j.choices?.[0]?.message?.content || j.error?.message || 'No response — load a model in oMLX');
    }}
  }} catch(e) {{ add('assistant', 'Error: ' + e.message); }}
}}
document.getElementById('send').onclick = send;
input.onkeydown = e => {{ if (e.key === 'Enter' && !e.shiftKey) {{ e.preventDefault(); send(); }} }};
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def _json(self, data: dict, code: int = 200):
        body = json.dumps(data, indent=2).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _html(self, body: str, code: int = 200):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?")[0].rstrip("/") or "/"
        routes = {
            "/": HUB_HTML,
            "/index.html": HUB_HTML,
            "/hub": HUB_HTML,
            "/agents/hermes": agent_chat_html(
                "hermes", "Hermes Chat", "Anthropic API via oMLX — quick agent chat", "anthropic"
            ),
            "/agents/openclaw": agent_chat_html(
                "openclaw",
                "OpenClaw Chat",
                "Simplified assistant — for full OpenClaw use Terminal",
                "openai",
            ),
        }
        if path in routes:
            return self._html(routes[path])
        if path in ("/api/status", "/hub/api/status"):
            return self._json(stack_status())
        if path in ("/api/downloads", "/hub/api/downloads"):
            return self._json(downloads_status())
        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        path = self.path.split("?")[0]
        if path not in ("/api/downloads/resume", "/hub/api/downloads/resume"):
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b"{}"
        try:
            data = json.loads(body.decode())
        except json.JSONDecodeError:
            return self._json({"error": "invalid json"}, 400)
        job_id = data.get("id", "all")
        ok = queue_download(job_id)
        self._json({"queued": ok, "id": job_id}, 200 if ok else 500)


def main():
    print(f"Stack Hub listening on :{PORT}")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
