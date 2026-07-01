# Local Inference Stack

Privacy-first local LLM stack for **Apple Silicon Mac** (optimized for M4 Pro 48GB).

One command installs oMLX, Ollama MLX, Open WebUI, Stack Hub, and agent configs for Cursor / OpenCode / OpenClaw / Hermes.

## Quick start

```bash
cd ~/Documents/GitHub/local-inference
make one-shot    # complete setup + model downloads
# or
make bootstrap   # fresh install
```

First run downloads ~80–120 GB of models and takes 30–90 minutes. Skip models during install:

```bash
SKIP_MODELS=1 make bootstrap
make update-models   # pull models later
```

## One bookmark

| What | URL |
|------|-----|
| **Stack Hub** (status, agents, models) | http://127.0.0.1:3080/hub |
| **Chat** (Open WebUI) | http://127.0.0.1:3080 |
| **oMLX admin** (load MLX models) | http://127.0.0.1:3080/omlx/admin |
| Ollama API | http://127.0.0.1:11434 |

**API key:** `mkapikey` (in `~/.config/local-inference/omlx.env`)

## Architecture

```
Cursor / OpenCode / OpenClaw / Hermes
         │
         ▼
    oMLX :8000  ◄── primary MLX server (agents)
         │
    Caddy :3080 ──► /      Open WebUI (chat + RAG)
                 ──► /hub  Stack Hub (status + agents)
                 ──► /omlx oMLX admin proxy
         │
    Ollama :11434  ◄── model-pull fallback + RAG embeddings
         │
    ~/models       ◄── MLX weights
```

## After bootstrap

**Cursor:** `make configure-cursor` — then switch Agent mode to your local model.

**Agents:** see [docs/agents-guide.md](docs/agents-guide.md) · launch from http://127.0.0.1:3080/hub

**Fable 5 locally:** see [docs/fable-local.md](docs/fable-local.md) — use Qwopus Fable5 4B + Qwen 35B

## Daily commands

```bash
make verify          # health check
make update-models   # sync catalog models (resumable)
make restart         # restart Docker stack
make logs            # tail logs
```

## Models (48 GB tier)

| Role | Model |
|------|-------|
| Primary | `qwen3.5:35b-a3b-coding-nvfp4` |
| Fast | `qwen2.5-coder:14b` |
| Fable-style agent | `Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit` |
| Embeddings | `nomic-embed-text` |
| Vision (optional) | `qwen2.5vl:7b` |

Edit [`models/catalog.yaml`](models/catalog.yaml) to add models.

## Work vs personal

Open WebUI **Knowledge Collections** — see [`docs/work-personal-workflows.md`](docs/work-personal-workflows.md)

## Privacy

All servers bind to `127.0.0.1`. See [`docs/privacy.md`](docs/privacy.md).

**Cursor Tab autocomplete is cloud-only** — Chat/Agent modes use your local model.

## Troubleshooting

[`docs/troubleshooting.md`](docs/troubleshooting.md) · live status at http://127.0.0.1:3080/hub

## License

MIT — configuration and scripts in this repo.
