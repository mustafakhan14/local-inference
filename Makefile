REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export REPO_ROOT
COMPOSE := docker compose -f $(REPO_ROOT)/config/docker-compose.yml

.PHONY: bootstrap verify update-models start stop restart logs start-webui stop-webui restart-omlx help one-shot dashboard-dev finish

help:
	@echo "Local Inference Stack — targets:"
	@echo "  make bootstrap      Full one-shot setup"
	@echo "  make one-shot       Complete setup + model downloads + stack hub"
	@echo "  make verify         Health check all services"
	@echo "  make update-models  Pull models from catalog"
	@echo "  make start          Start all services"
	@echo "  make stop           Stop Docker stack (Ollama/oMLX via launchd)"
	@echo "  make restart        stop + start"
	@echo "  make logs           Tail service logs"
	@echo ""
	@echo "Options:"
	@echo "  SKIP_MODELS=1 make bootstrap     Skip large model downloads"
	@echo "  SKIP_DOCKER=1 make bootstrap     Skip Open WebUI"

bootstrap:
	@chmod +x $(REPO_ROOT)/scripts/*.sh $(REPO_ROOT)/scripts/lib/*.sh 2>/dev/null || true
	@$(REPO_ROOT)/scripts/bootstrap.sh

one-shot finish:
	@chmod +x $(REPO_ROOT)/scripts/*.sh $(REPO_ROOT)/scripts/lib/*.sh 2>/dev/null || true
	@$(REPO_ROOT)/scripts/finish-setup.sh

verify:
	@$(REPO_ROOT)/scripts/verify-setup.sh

update-models:
	@$(REPO_ROOT)/scripts/pull-models.sh

start: start-ollama start-omlx start-webui
	@echo "Stack started. Hub: http://127.0.0.1:3080/hub"

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
	@echo "Docker stack stopped. Ollama/oMLX launchd agents still run on login."

restart: stop start

restart-omlx:
	@launchctl kickstart -k gui/$$(id -u)/com.omlx.serve 2>/dev/null || open -a oMLX

logs:
	@echo "=== ollama ===" && tail -20 $(HOME)/Library/Logs/local-inference/ollama.log 2>/dev/null || true
	@echo "=== omlx ===" && tail -20 $(HOME)/Library/Logs/local-inference/omlx.log 2>/dev/null || true
	@echo "=== open-webui ===" && docker logs open-webui --tail 20 2>/dev/null || true
	@echo "=== gateway ===" && docker logs local-inference-gateway --tail 20 2>/dev/null || true

configure-cursor:
	@$(REPO_ROOT)/scripts/configure-cursor.sh
