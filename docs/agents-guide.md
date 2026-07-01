# Which agent tool when?

**Start at http://127.0.0.1:3080/hub** — tabs for Downloads, Status, Agents, Terminal.

| Tool | What it is | Use when | Launch |
|------|------------|----------|--------|
| **Cursor Agent** | IDE agent with tools + MCP | Daily coding in repos | Settings → local model + Agent mode |
| **OpenCode** | Terminal coding agent | Multi-file edits, shell | Terminal tab → copy `opencode.sh` |
| **OpenClaw** | Personal assistant | Tasks, automation | [OpenClaw Chat](/hub/agents/openclaw) or Terminal |
| **Hermes** | General agent CLI | Open-ended agent tasks | [Hermes Chat](/hub/agents/hermes) or Terminal |
| **Open WebUI** | Browser chat + RAG | General chat, Knowledge Collections | http://127.0.0.1:3080 |

## Chat vs Terminal

| Mode | Best for |
|------|----------|
| **Hermes / OpenClaw Chat** (`/hub/agents/*`) | Quick questions, planning, lightweight assistant |
| **Terminal** (`/hub/#terminal`) | Full agent sessions with tools, shell, file access |
| **Open WebUI** | Document RAG, general chat |

OpenClaw Chat is a **simplified oMLX-backed assistant**, not the full OpenClaw runtime. For full OpenClaw, use the Terminal tab.

## oMLX one-liners

```bash
omlx launch opencode
omlx launch openclaw --tools-profile coding
omlx launch hermes
```

Or: http://127.0.0.1:3080/omlx/admin → Applications

## Downloads

Track Qwen 35B and Fable5 progress: http://127.0.0.1:3080/hub/#downloads

Resume from CLI: `make resume-downloads`
