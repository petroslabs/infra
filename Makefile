# =============================================================================
# PetrosLabs infra — Makefile
# =============================================================================

.DEFAULT_GOAL := help

GREEN  := \033[0;32m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
RESET  := \033[0m

.PHONY: help
help: ## Afficher cette aide
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$|^## )' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "} /^## /{printf "\n$(YELLOW)%s$(RESET)\n", substr($$0,4)} /^[a-zA-Z_-]+/{printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'

DOCKER_COMP      = docker compose
DOCKER_COMP_PROD = docker compose --env-file .env.docker -f compose.prod.yaml

## —— Développement ———————————————————————————————————————————————————————————

.PHONY: up
up: certs ## Lever le reverse proxy (dev)
	$(DOCKER_COMP) up -d
	@echo "$(GREEN)✔ Reverse proxy levé — tableau de bord : https://$$(grep '^TRAEFIK_DOMAIN=' .env 2>/dev/null | cut -d= -f2 || echo traefik.localhost)$(RESET)"

.PHONY: down
down: ## Abaisser le reverse proxy (dev)
	$(DOCKER_COMP) down

.PHONY: logs
logs: ## Suivre les logs de Traefik (dev)
	$(DOCKER_COMP) logs -f traefik

.PHONY: ps
ps: ## Afficher l'état des conteneurs
	$(DOCKER_COMP) ps

.PHONY: certs
certs: ## Engendrer les certificats TLS de développement (mkcert)
	@if ! which mkcert > /dev/null 2>&1; then \
		echo "$(YELLOW)⚠ mkcert n'est pas installé : https://github.com/FiloSottile/mkcert$(RESET)"; \
		exit 1; \
	fi
	@mkcert -install 2>/dev/null || true
	@mkdir -p docker/traefik/certs
	@# "*.localhost" ne couvre qu'UNE étiquette, et OpenSSL refuse un joker
	@# placé directement sous un domaine de premier niveau pour certaines
	@# vérifications strictes (comme il refuse "*.fr") — d'où l'ajout explicite
	@# de domaines ici au besoin, via DOMAINS="mon-projet.localhost ...".
	@# Le contrôle demande à OpenSSL si le certificat vaut pour chaque nom
	@# demandé, plutôt que de se fier à la seule présence du fichier : un
	@# certificat engendré avant qu'un projet rejoigne ce proxy ne le couvrirait
	@# pas, et resterait pourtant en place sans régénération.
	@missing=0; \
	for host in localhost $(DOMAINS); do \
		openssl x509 -in docker/traefik/certs/local-cert.pem -noout -checkhost "$$host" 2>/dev/null \
			| grep -q "does match" || missing=1; \
	done; \
	if [ "$$missing" = 1 ]; then \
		existing=$$(openssl x509 -in docker/traefik/certs/local-cert.pem -noout -ext subjectAltName 2>/dev/null \
			| grep -oE 'DNS:[^,]+' | sed 's/DNS://'); \
		mkcert \
			-cert-file docker/traefik/certs/local-cert.pem \
			-key-file docker/traefik/certs/local-key.pem \
			"localhost" "*.localhost" $(DOMAINS) $$existing; \
		$(DOCKER_COMP) restart traefik 2>/dev/null || true; \
	fi
	@echo "$(GREEN)✔ Certificats TLS présents$(RESET)"

## —— Production (VPS) ————————————————————————————————————————————————————————
# .env.docker (non versionné, cf. .env.docker.example) porte ACME_EMAIL et
# ACME_CA_SERVER.

.PHONY: up-prod
up-prod: ## Lever le reverse proxy (production, Let's Encrypt)
	@# ACME_EMAIL est obligatoire : la pile refuse de démarrer sans, plutôt que
	@# d'échouer plus tard sur un enregistrement de compte incompréhensible.
	@# Pour un premier déploiement, viser d'abord le bac à sable via
	@# ACME_CA_SERVER (cf. .env.docker.example) — la production limite à cinq
	@# échecs de validation par heure et cinquante certificats par domaine et
	@# par semaine.
	$(DOCKER_COMP_PROD) up -d
	@echo "$(GREEN)✔ Reverse proxy de production levé$(RESET)"

.PHONY: down-prod
down-prod: ## Abaisser le reverse proxy (production)
	$(DOCKER_COMP_PROD) down

.PHONY: logs-prod
logs-prod: ## Suivre les logs de Traefik (production)
	$(DOCKER_COMP_PROD) logs -f traefik

.PHONY: ps-prod
ps-prod: ## Afficher l'état des conteneurs (production)
	$(DOCKER_COMP_PROD) ps
