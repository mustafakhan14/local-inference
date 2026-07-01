# Work vs personal workflows

Keep work and personal AI contexts separate using workspace boundaries, not separate machines.

## Document RAG (Open WebUI)

After first login at http://127.0.0.1:3080:

1. Go to **Workspace** → **Knowledge**
2. Create collection **Work** — employer projects, client docs, internal specs
3. Create collection **Personal** — side projects, learning, personal notes
4. In chat, attach a collection via **#** or the knowledge picker

Each collection has its own document corpus. Use separate browser profiles for extra isolation if needed.

Setup guide: `~/.config/local-inference/open-webui/workspaces.md`

## Stack Hub

Status, agents, model downloads: http://127.0.0.1:3080/hub

## Code projects (Cursor)

1. Copy the privacy rule into each repo:
   ```bash
   cp ~/Documents/GitHub/local-inference/cursor/templates/local-privacy.mdc \
      /path/to/project/.cursor/rules/local-privacy.mdc
   ```
2. Use separate git directories: `~/Projects/work/` vs `~/Projects/personal/`
3. Toggle cloud models off when opening work repos

## Model selection by task

| Task | Model | Backend |
|------|-------|---------|
| Complex coding / agents | Qwen 35B | oMLX |
| Quick questions / small edits | Qwen2.5 Coder 14B | Ollama |
| Fable-style fast agent | Qwopus Fable5 4B | oMLX |
| Document Q&A | Workspace default | Open WebUI RAG → Ollama embeddings |
| Vision / screenshots | Qwen2.5 VL 7B | Ollama (optional) |

## Switching contexts

Only one large model should be loaded at a time on 48GB RAM. oMLX evicts idle models via LRU:

- Use the **fast** Ollama model when you do not need frontier quality
- Unload models at http://127.0.0.1:3080/omlx/admin before starting a long agent session
