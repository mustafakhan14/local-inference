# Troubleshooting

## Quick diagnostics

```bash
make verify
make logs
```

Live status: http://127.0.0.1:3080/hub

## oMLX not responding

1. Check if the app is running: `pgrep -l oMLX` or open **oMLX** from Applications
2. Open admin UI: http://127.0.0.1:3080/omlx/admin
3. Verify API key in `~/.config/local-inference/omlx.env`
4. Test:
   ```bash
   source ~/.config/local-inference/omlx.env
   curl -s -H "Authorization: Bearer $OMLX_API_KEY" http://127.0.0.1:8000/v1/models
   ```
5. Restart: `make restart-omlx`

## Ollama not responding (`:11434`)

```bash
curl http://127.0.0.1:11434/api/tags
brew services restart ollama
# or
launchctl kickstart -k gui/$(id -u)/com.ollama.serve
```

## Stack Hub or Open WebUI not loading

```bash
docker ps | grep -E 'caddy|open-webui|stack-hub'
docker logs stack-hub --tail 50
docker logs local-inference-caddy --tail 50
make start
```

Ensure oMLX and Ollama are up. Backends use `host.docker.internal`.

## Out of memory / slow inference

- Close Chrome tabs and Docker containers you are not using
- Use `qwen2.5-coder:14b` instead of the 35B model
- Reduce context length in client settings (32K → 16K)
- Plug in power and improve laptop airflow (thermal throttling)
- Check Activity Monitor → Memory Pressure

## MLX backend not active (Ollama)

Ollama MLX requires 32GB+ RAM and supported models (Qwen3.5 family). Check logs:

```bash
tail -f ~/Library/Logs/local-inference/ollama.log
```

Look for `backend=mlx` in output. Models without MLX support fall back to Metal/llama.cpp automatically.

## Cursor not connecting

1. Base URL must be `http://localhost:8000/v1` (include `/v1`)
2. API key must match `OMLX_API_KEY` in `~/.config/local-inference/omlx.env`
3. Model name must exactly match `GET /v1/models` output
4. Disable all cloud models to avoid routing conflicts

## Model download failures

```bash
make update-models   # resumable HF + Ollama pulls
```

Progress visible at http://127.0.0.1:3080/hub

```bash
# Manual resume
hf download shuhulx/Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit \
  --local-dir ~/models/Qwopus3.5-4B-Coder-Fable5-v1-MLX-4bit --resume-download
ollama pull qwen3.5:35b-a3b-coding-nvfp4
```

## Reset Docker stack

```bash
make stop
docker compose -f config/docker-compose.yml down -v  # removes chat history
make start
```
