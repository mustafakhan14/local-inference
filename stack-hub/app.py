#!/usr/bin/env python3
"""Stack Hub — status, downloads, agents, terminal launcher."""
from __future__ import annotations

import json
import mimetypes
import os
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get("STACK_HUB_PORT", "8780"))
OMLX_HOST = os.environ.get("OMLX_HOST", "host.docker.internal")
OMLX_PORT = os.environ.get("OMLX_PORT", "8000")
OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "host.docker.internal")
OLLAMA_PORT = os.environ.get("OLLAMA_PORT", "11434")
OMLX_KEY = os.environ.get("OMLX_API_KEY", "mkapikey")
MODELS_DIR = Path(os.environ.get("MODELS_DIR", "/models"))
HOME_CONFIG = Path(os.environ.get("HOME_CONFIG", "/home-config"))
LOG_DIR = Path(os.environ.get("LOG_DIR", "/logs"))
BASE_URL = os.environ.get("PUBLIC_BASE_URL", "http://127.0.0.1:3080")
STATIC_DIR = Path(__file__).parent / "static"

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
        "dir_name": "Qwen3.5-35B-A3B-Instruct-4bit",
        "expected_gb": 20,
    },
    {
        "id": "fable-agent",
        "name": "Fable5 MLX (4B)",
        "backend": "mlx",
        "dir_name": "Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit",
        "expected_gb": 2.5,
    },
]

TABS = ["downloads", "status", "agents", "terminal"]


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
        return [line[:200] for line in lines[-n:]]
    except OSError:
        return []


def watcher_up() -> bool:
    log_file = LOG_DIR / "download-watcher.log"
    if log_file.is_file():
        try:
            return (time.time() - log_file.stat().st_mtime) < 30
        except OSError:
            pass
    err_file = LOG_DIR / "download-watcher.err.log"
    if err_file.is_file():
        try:
            err = err_file.read_text(errors="replace")
            if "Operation not permitted" in err:
                return False
        except OSError:
            pass
    return True


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
        progress = 100 if complete else 0
        status = "complete" if complete else ("downloading" if is_active else "missing")
        return {**job, "size_gb": expected if complete else 0.0, "progress_pct": progress, "status": status}

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
    downloading, active = download_pid_alive()
    return {
        "jobs": [job_status(j) for j in DOWNLOAD_JOBS],
        "active_job": active if downloading else None,
        "watcher_up": watcher_up(),
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
    agents_dir = HOME_CONFIG / "agents"
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
        "downloads": downloads_status(),
        "agents": {
            "hermes": {
                "name": "Hermes",
                "cmd": str(agents_dir / "hermes.sh"),
                "chat": f"{BASE_URL}/hub/agents/hermes",
            },
            "openclaw": {
                "name": "OpenClaw",
                "cmd": str(agents_dir / "openclaw.sh"),
                "chat": f"{BASE_URL}/hub/agents/openclaw",
            },
            "opencode": {"name": "OpenCode", "cmd": str(agents_dir / "opencode.sh")},
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


def hub_html(active_tab: str = "downloads") -> str:
    if active_tab not in TABS:
        active_tab = "downloads"
    tabs_html = "".join(
        f'<a class="tab{" active" if t == active_tab else ""}" href="/hub/?tab={t}" data-tab="{t}">{t.title()}</a>'
        for t in TABS
    )
    panels = "".join(
        f'<div id="{t}" class="panel{" active" if t == active_tab else ""}">'
        + {
            "downloads": """
  <p id="watcher-warn" class="watcher-warn" style="display:none">Download watcher offline — run: make install-host-scripts</p>
  <div class="dl-grid" id="dl-grid"></div>
  <div class="logbox" id="dl-log"></div>""",
            "status": '<div class="grid" id="status-grid"></div>',
            "agents": """
  <div class="card">
    <h2>Quick chat (browser)</h2>
    <ul>
      <li><a href="/hub/agents/hermes">Hermes Chat</a></li>
      <li><a href="/hub/agents/openclaw">OpenClaw Chat</a></li>
    </ul>
    <p class="sub" style="margin-top:10px">Full agent sessions → Terminal tab</p>
  </div>
  <div class="grid" id="agents-grid" style="margin-top:12px"></div>""",
            "terminal": """
  <div class="agent-btns">
    <button type="button" class="btn secondary" data-copy="hermes">Copy Hermes cmd</button>
    <button type="button" class="btn secondary" data-copy="openclaw">Copy OpenClaw cmd</button>
    <button type="button" class="btn secondary" data-copy="opencode">Copy OpenCode cmd</button>
  </div>
  <p class="sub">Paste into terminal below.</p>
  <iframe class="term" src="/hub/terminal/" title="Agent terminal"></iframe>""",
        }[t]
        + "</div>"
        for t in TABS
    )
    cmds = {
        "hermes": str(HOME_CONFIG / "agents/hermes.sh"),
        "openclaw": str(HOME_CONFIG / "agents/openclaw.sh"),
        "opencode": str(HOME_CONFIG / "agents/opencode.sh"),
    }
    return f"""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/><title>Stack Hub</title>
<link rel="stylesheet" href="/hub/static/hub.css"/>
</head><body>
<div class="nav">
  <a href="/">Chat</a>
  <a href="/hub/">Hub</a>
  <a href="/hub/?tab=downloads">Downloads</a>
  <a href="/hub/?tab=terminal">Terminal</a>
  <a href="/hub/agents/hermes">Hermes Chat</a>
  <a href="/hub/agents/openclaw">OpenClaw Chat</a>
  <a href="/omlx/admin">oMLX Admin</a>
</div>
<h1>Local AI Stack Hub</h1>
<p class="sub">API key <code>mkapikey</code></p>
<div class="tabs">{tabs_html}</div>
{panels}
<div id="toast" class="toast"></div>
<script>window.HUB_CMDS = {json.dumps(cmds)};</script>
<script src="/hub/static/hub.js"></script>
</body></html>"""


def agent_chat_html(agent: str, title: str, subtitle: str, api_mode: str) -> str:
    system = (
        "You are Hermes, a helpful local AI agent. Be concise and actionable."
        if agent == "hermes"
        else "You are a personal assistant (OpenClaw-style). Help with tasks and planning. "
        "For full OpenClaw with tools, use the Terminal tab."
    )
    return f"""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/><title>{title}</title>
<link rel="stylesheet" href="/hub/static/hub.css"/>
</head><body>
<div class="nav">
  <a href="/">Chat</a>
  <a href="/hub/">Hub</a>
  <a href="/hub/agents/hermes">Hermes Chat</a>
  <a href="/hub/agents/openclaw">OpenClaw Chat</a>
</div>
<h1>{title}</h1>
<p class="sub">{subtitle}</p>
<div class="chat-wrap">
  <div class="chat-log" id="log"></div>
  <div class="chat-input">
    <textarea id="input" placeholder="Message..."></textarea>
    <button type="button" class="btn" id="send">Send</button>
  </div>
</div>
<script>window.AGENT_CHAT = {json.dumps({"apiMode": api_mode, "system": system})};</script>
<script src="/hub/static/agent-chat.js"></script>
</body></html>"""


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

    def _static(self, name: str):
        path = STATIC_DIR / name
        if not path.is_file():
            self.send_response(404)
            self.end_headers()
            return
        data = path.read_bytes()
        ctype = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_HEAD(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        if path in ("/", "/index.html", "/hub"):
            data = hub_html((parse_qs(parsed.query).get("tab") or ["downloads"])[0]).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            return
        self.send_response(404)
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        qs = parse_qs(parsed.query)
        tab = (qs.get("tab") or ["downloads"])[0]

        if path in ("/static/hub.css", "/hub/static/hub.css"):
            return self._static("hub.css")
        if path in ("/static/hub.js", "/hub/static/hub.js"):
            return self._static("hub.js")
        if path in ("/static/agent-chat.js", "/hub/static/agent-chat.js"):
            return self._static("agent-chat.js")

        if path in ("/", "/index.html", "/hub"):
            return self._html(hub_html(tab))

        if path == "/agents/hermes":
            return self._html(agent_chat_html("hermes", "Hermes Chat", "Anthropic API via oMLX", "anthropic"))
        if path == "/agents/openclaw":
            return self._html(
                agent_chat_html("openclaw", "OpenClaw Chat", "Simplified assistant — use Terminal for full OpenClaw", "openai")
            )
        if path in ("/api/status", "/hub/api/status"):
            return self._json(stack_status())
        if path in ("/api/downloads", "/hub/api/downloads"):
            return self._json(downloads_status())

        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        path = urlparse(self.path).path
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
