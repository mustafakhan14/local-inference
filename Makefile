REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export REPO_ROOT
COMPOSE := docker compose -f $(REPO_ROOT)/config/docker-compose.yml

.PHONY: bootstrap verify update-models resume-downloads start stop restart logs start-webui stop-webui restart-omlx help one-shot one-shot-agents dashboard-dev finish

help:
	@echo "Local Inference Stack — targets:"
	@echo "  make bootstrap         Full one-shot setup"
	@echo "  make one-shot          Complete setup + model downloads + stack hub"
	@echo "  make one-shot-agents   Hub UI + terminal + resume downloads"
	@echo "  make resume-downloads  Resume Qwen 35B + Fable5 downloads"
	@echo "  make verify            Health check all services"
	@echo "  make update-models     Pull models from catalog"
	@echo "  make start             Start all services"
	@echo "  make stop              Stop Docker stack"
	@echo "  make restart           stop + start"
	@echo "  make logs              Tail service logs"

bootstrap:
	@chmod +x $(REPO_ROOT)/scripts/*.sh $(REPO_ROOT)/scripts/lib/*.sh 2>/dev/null || true
	@$(REPO_ROOT)/scripts/bootstrap.sh

one-shot finish:
	@chmod +x $(REPO_ROOT)/scripts/*.sh 2>/dev/null || true
	@$(REPO_ROOT)/scripts/finish-setup.sh

one-shot-agents:
	@chmod +x $(REPO_ROOT)/scripts/*.sh 2>/dev/null || true
	@$(REPO_ROOT)/scripts/one-shot-agents.sh

resume-downloads:
	@chmod +x $(REPO_ROOT)/scripts/*.sh 2>/dev/null || true
	@$(REPO_ROOT)/scripts/resume-download.sh all

verify:
	@$(REPO_ROOT)/scripts/verify-setup.sh

update-models:
	@$(REPO_ROOT)/scripts/pull-models.sh

start: start-ollama start-omlx start-webui start-host-services
	@echo "Stack started. Hub: http://127.0.0.1:3080/hub"

start-host-services:
	@launchctl kickstart -k gui/$$(id -u)/com.local-inference.download-watcher 2>/dev/null || \
		bash $(REPO_ROOT)/scripts/download-watcher.sh &>/dev/null &
	@launchctl kickstart -k gui/$$(id -u)/com.local-inference.terminal 2>/dev/null || \
		bash $(REPO_ROOT)/scripts/install-agent-terminal.sh 2>/dev/null || true

start-ollama:
	@launchctl kickstart -k gui/$$(id -u)/com.ollama.serve 2>/dev/null || brew services start ollama || true

start-omlx:
	@open -a oMLX 2>/dev/null || true

start-webui:
	@OMLX_API_KEY=mkapikey $(COMPOSE) up -d --build 2>/dev/null || \
		OMLX_API_KEY=mkapikey $(REPO_ROOT)/scripts/install-open-webui.sh

dashboard-dev:
	@OMLX_API_KEY=mkapikey python3 $(REPO_ROOT)/scripts/dashboard.py

configure-omlx:
	@$(REPO_ROOT)/scripts/configure-omlx.sh

setup-mcp:
	@$(REPO_ROOT)/scripts/setup-mcp.sh

stop:
	@$(COMPOSE) down 2>/dev/null || true
	@echo "Docker stack stopped."

restart: stop start

restart-omlx:
	@launchctl kickstart -k gui/$$(id -u)/com.omlx.serve 2>/dev/null || open -a oMLX

logs:
	@echo "=== pull-models ===" && tail -15 $(HOME)/Library/Logs/local-inference/pull-models.log 2>/dev/null || true
	@echo "=== download-watcher ===" && tail -10 $(HOME)/Library/Logs/local-inference/download-watcher.log 2>/dev/null || true
	@echo "=== terminal ===" && tail -10 $(HOME)/Library/Logs/local-inference/terminal.log 2>/dev/null || true
	@echo "=== gateway ===" && docker logs local-inference-gateway --tail 15 2>/dev/null || true

configure-cursor:
	@$(REPO_ROOT)/scripts/configure-cursor.sh
