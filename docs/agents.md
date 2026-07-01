# Agentic workflows on your local stack

This stack supports **agent-grade** workflows — multi-step reasoning, tool use, file edits, and MCP — not just chat completion.

## What "agentic" means here

| Capability | Supported? | How |
|------------|------------|-----|
| Multi-turn tool calling | Yes | oMLX + Qwen 3.5 (OpenAI `tools` / function calling) |
| File read/write via tools | Yes | Cursor Agent, OpenCode, Claude Code, Open WebUI |
| MCP (filesystem, git, fetch) | Yes | `scripts/setup-mcp.sh` → `~/.cursor/mcp.json` |
| Terminal command execution | Yes | OpenCode, Claude Code, Cursor Agent |
| SSD KV cache for agent loops | Yes | oMLX (main advantage over plain Ollama for agents) |
| Sub-agents / parallel agents | Partial | OpenCode; Cursor subagents need cloud models today |

## Recommended agent paths

### 1. Cursor Agent (your IDE — closest to "like Auto")

**Best for:** codebase work in this repo and other projects.

1. Run `make configure-cursor`
2. Cursor Settings → Models:
   - Override OpenAI Base URL: `http://127.0.0.1:8000/v1`
   - API Key: from `~/.config/local-inference/omlx.env`
   - Model: `qwen3.5:35b-a3b-coding-nvfp4` (Ollama) or your oMLX model name
3. **Disable cloud models** for sensitive work
4. Use **Agent mode** (not just Chat) — this enables tool use
5. Run `make setup-mcp` and restart Cursor for filesystem/git MCP tools

**Limits vs cloud Cursor Agent:**
- Smaller model = less capable planning on huge refactors
- Tab autocomplete stays cloud-only
- Very long agent runs may be slower (but private)

### 2. OpenCode (terminal agent)

```bash
source ~/.config/local-inference/agents.env
opencode
```

Config: `~/.config/opencode/opencode.json` — uses oMLX with `tools: true`.

**Best for:** autonomous terminal sessions, scripting, CI-like tasks.

### 3. Claude Code (Anthropic API → local)

```bash
~/.config/local-inference/claude-local.sh --model qwen3.5:35b-a3b-coding-nvfp4
```

oMLX exposes `/v1/messages` (Anthropic-compatible). Same UX as Claude Code, zero cloud.

### 4. Open WebUI Knowledge + chat

Use Knowledge Collections for document-centric Q&A. Stack Hub at http://127.0.0.1:3080/hub lists all agent launchers.

### 5. Open WebUI + Pipelines

For custom Python agent logic, use Open WebUI Pipelines (advanced).

## Model requirements for agents

Agents need models with **reliable tool/function calling**:

| Model | Tool calling | Agent grade |
|-------|--------------|-------------|
| `qwen3.5:35b-a3b-coding-nvfp4` | Excellent | Primary choice |
| `qwen2.5-coder:14b` | Good | Fast tasks only |
| Generic 7B chat models | Poor | Not recommended for agents |

## oMLX agent optimizations

- **Paged SSD KV cache:** agent sessions reuse prefixes across turns (5s vs 90s TTFT on long contexts)
- **Continuous batching:** multiple concurrent requests
- **MCP integration:** enable in oMLX admin dashboard

## Honest comparison to cloud agents (Claude/GPT in Cursor)

| | Cloud (Auto/Claude) | Your local stack |
|--|-------------------|------------------|
| Privacy | Data leaves device | 100% on-device |
| Planning depth | Frontier (Opus/GPT-4 class) | Qwen 35B — strong but not frontier |
| Speed per turn | Fast (datacenter GPU) | 25–50 tok/s — good with oMLX cache |
| Cost | Subscription/API | Free after setup |
| Tool/MCP | Full | Full (with right model + client) |

For most day-to-day coding agents on a single repo, **Qwen 35B + Cursor Agent + MCP** is genuinely usable. For multi-repo megarefactors, you may still want cloud for hardest tasks.

## Quick test: verify tool calling

```bash
source ~/.config/local-inference/omlx.env
curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H "Authorization: Bearer $OMLX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.5:35b-a3b-coding-nvfp4",
    "messages": [{"role": "user", "content": "What is 2+2?"}],
    "max_tokens": 50
  }' | jq .
```

If using Ollama directly while oMLX loads MLX weights:

```bash
curl -s http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:14b",
    "messages": [{"role": "user", "content": "Say hello"}],
    "max_tokens": 20
  }' | jq .
```
