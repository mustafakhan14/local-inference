# Which agent tool when?

Quick guide for the tools in your stack. **Start at http://127.0.0.1:3080/hub** for live status and launch commands.

| Tool | What it is | Use when | Launch |
|------|------------|----------|--------|
| **Cursor Agent** | IDE agent with tools + MCP | Daily coding in repos, like this chat | Settings → local model + Agent mode |
| **OpenCode** | Terminal coding agent | Multi-file edits, shell commands, no GUI | `~/.config/local-inference/agents/opencode.sh` |
| **OpenClaw** | Personal assistant agent | Tasks, messaging, automation across apps | `~/.config/local-inference/agents/openclaw.sh` |
| **Hermes** | General-purpose agent CLI | Open-ended agent tasks via Anthropic API shape | `~/.config/local-inference/agents/hermes.sh` |
| **Claude Code (local)** | Anthropic's coding agent UX | Familiar Claude Code workflow, fully local | `~/.config/local-inference/claude-local.sh` |
| **Open WebUI** | Browser chat + RAG | General chat, Work/Personal knowledge collections | http://127.0.0.1:3080 |

## Decision tree

```
Need to edit code in a repo?
  └─ Yes → Cursor Agent or OpenCode
  └─ No → Need documents?
       └─ Yes → Open WebUI Knowledge Collection (Work / Personal)
       └─ No → General chat → Open WebUI
```

## oMLX one-liners (from terminal)

```bash
omlx launch opencode    # pick model in TUI
omlx launch openclaw --tools-profile coding
omlx launch claude      # Claude Code → local
omlx launch hermes      # if installed
```

All use API key `mkapikey` and http://127.0.0.1:8000.

Or launch from **oMLX Applications** tab: http://127.0.0.1:3080/omlx/admin

## Stack Hub

Live status, model download progress, agent commands: http://127.0.0.1:3080/hub
