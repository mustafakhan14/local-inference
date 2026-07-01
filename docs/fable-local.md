# Claude Fable 5 — local alternatives

**Claude Fable 5 cannot run locally.** It is Anthropic's proprietary cloud model.

## Closest local options on M4 Pro 48GB

| Option | What it is | Agent grade | Size |
|--------|------------|-------------|------|
| **Qwen 3.5 35B-A3B** | Primary — best tool calling + coding | Best overall | ~20 GB |
| **Qwopus Fable5 4B MLX** | Trained on Fable-5 agent traces | Best Fable-*style* agent | ~2.5 GB |
| **Qwable 3.6 27B** | Fable-style step reasoning mimic | Reasoning format | ~17 GB |

## Recommendation

1. **Cursor / OpenCode agents:** `qwen3.5:35b-a3b-coding-nvfp4`
2. **Fable trace-style fast agent:** `Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit` (downloading to `~/models/`)
3. **Long structured reasoning:** Qwable 27B via oMLX admin → Downloads

## Using Qwopus Fable5 in oMLX

1. Open http://127.0.0.1:3080/omlx/admin → **Models** — it should appear after download
2. Load model → use in **Applications** tab for OpenCode / Hermes
3. Or: `omlx launch opencode` and pick the Fable5 model

```bash
# Already pulled by finish-setup; or manually:
huggingface-cli download shuhulx/Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit \
  --local-dir ~/models/Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit
```

Then restart oMLX from the menu bar.

## Honest expectation

Qwopus mimics Fable's **tool-use traces**, not Anthropic frontier intelligence. For serious agentic coding, **Qwen 35B** remains the ceiling on 48GB RAM.
