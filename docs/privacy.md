# Privacy and data handling

All inference in this stack runs on your Mac. Nothing is sent to cloud providers unless you explicitly configure one.

## What stays local

| Component | Data that stays on-device |
|-----------|---------------------------|
| oMLX (`:8000`) | All prompts, completions, KV cache (RAM + SSD) |
| Ollama (`:11434`) | All prompts and model weights |
| Open WebUI (`:3080`) | Chat history in Docker volume `open-webui-data` |
| Stack Hub (`:3080/hub`) | Status probes only — no user data stored |
| OpenCode / OpenClaw / Hermes | Terminal agent traffic to localhost only |

## Network binding

All servers bind to `127.0.0.1` only:

- Stack entry: `127.0.0.1:3080` (chat, hub, oMLX proxy)
- oMLX direct: `127.0.0.1:8000`
- Ollama: `127.0.0.1:11434`

oMLX requires a local API key on every request to prevent accidental cross-process access.

## Cursor limitations

**Cursor Tab (inline autocomplete) is cloud-only.** It cannot be pointed at a local model. This is a Cursor product limitation, not a stack limitation.

For sensitive work:

1. Disable all cloud models in **Cursor Settings → Models**
2. Enable **Override OpenAI Base URL** → `http://localhost:8000/v1`
3. Use Chat and Agent modes only (these respect your local endpoint)
4. Optionally install [Continue.dev](https://continue.dev/) for local inline completions

## Optional hardening

- macOS **System Settings → Network → Firewall**: enable and block incoming connections for non-essential apps
- Never add cloud API keys to Open WebUI unless you accept that data may leave your machine
- Copy `cursor/templates/local-privacy.mdc` into sensitive project repos as `.cursor/rules/local-privacy.mdc`

## Secrets location

Generated secrets live in `~/.config/local-inference/` (not committed to git):

- `omlx.env` — API key and ports
- `state.env` — bootstrap timestamps and paths
