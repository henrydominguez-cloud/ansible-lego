# ACME Ansible — convenience wrapper around ansible-playbook / ansible-vault.
# It adds NO logic; it just shortens the long commands. See README.md.
#
# Override variables on the CLI:
#   make deploy ENV=alpha-dev PB=alpha-hello
#   make lab-run PB=alpha-notes            # deploy in the local lab
#   make new-brick NAME=myapp              # scaffold a component

ENV   ?= alpha-prod
PB    ?= site
TAGS  ?=
EXTRA ?=

INV    = inventory/$(ENV)
PLAY   = playbooks/$(PB).yml
VAULTF = $(INV)/group_vars/all/vault.yml
# Use the vault password file only if it exists (so vault-less runs still work).
VAULT  = $(if $(wildcard .vault_pass),--vault-password-file .vault_pass,)
TAGARG = $(if $(TAGS),--tags $(TAGS),)

.DEFAULT_GOAL := help

.PHONY: help deps lint syntax syntax-all check deploy new-brick new-service \
        vault-init vault-edit vault-view vault-encrypt vault-decrypt vault-rekey \
        sparse sparse-role \
        lab-up lab-down lab-ps lab-shell lab-syntax lab-check lab-run lab-idem

new-brick:  ## Scaffold a new brick from the skeleton: make new-brick NAME=myapp
	@test -n "$(NAME)" || { echo "Usage: make new-brick NAME=<name>"; exit 2; }
	@test ! -d "roles/components/$(NAME)" || { echo "roles/components/$(NAME) already exists"; exit 2; }
	@cp -R skeletons/component "roles/components/$(NAME)"
	@grep -rl '__COMPONENT__' "roles/components/$(NAME)" | xargs perl -pi -e 's/__COMPONENT__/$(NAME)/g'
	@echo "Created roles/components/$(NAME). Next: edit its tasks/defaults, then reference it from a service's meta."

new-service:  ## Scaffold a new service from the skeleton: make new-service NAME=my-app
	@test -n "$(NAME)" || { echo "Usage: make new-service NAME=<name>"; exit 2; }
	@test ! -d "roles/services/$(NAME)" || { echo "roles/services/$(NAME) already exists"; exit 2; }
	@cp -R skeletons/service "roles/services/$(NAME)"
	@grep -rl '__SERVICE__' "roles/services/$(NAME)" | xargs perl -pi -e 's/__SERVICE__/$(NAME)/g'
	@echo "Created roles/services/$(NAME). Next: set its bricks in meta/main.yml, add a playbook + host group."

# ── Local Docker test lab (see docs/local-testing.md) ──
LAB_PLATFORM ?= linux/arm64                # linux/arm64 (fast) | linux/amd64 (full, emulated)
LAB_COMPOSE   = LAB_PLATFORM=$(LAB_PLATFORM) docker compose -f lab/docker-compose.yml
LAB_INV       = lab/inventory
C            ?= rocky9a                  # target container for lab-shell
# lab targets use PB (default 'site'); for a focused test pass e.g. PB=alpha-hello

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

deps:  ## Install required Ansible collections
	ansible-galaxy collection install -r requirements.yml

lint:  ## Run yamllint + ansible-lint
	yamllint .
	ansible-lint

syntax:  ## Syntax-check one playbook (PB) against ENV
	ansible-playbook -i $(INV) $(PLAY) --syntax-check

syntax-all:  ## Syntax-check every playbook against ENV
	@for pb in playbooks/*.yml; do \
	  printf '%-28s ' "$$(basename $$pb)"; \
	  ansible-playbook -i $(INV) "$$pb" --syntax-check >/dev/null && echo OK || echo FAIL; \
	done

check:  ## Dry-run: --check --diff (PB on ENV, optional TAGS/EXTRA)
	ansible-playbook -i $(INV) $(PLAY) --check --diff $(VAULT) $(TAGARG) $(EXTRA)

deploy:  ## Deploy for real (PB on ENV, optional TAGS/EXTRA)
	ansible-playbook -i $(INV) $(PLAY) $(VAULT) $(TAGARG) $(EXTRA)

vault-init:  ## Create ENV vault.yml from the example (then edit + encrypt)
	cp -n $(INV)/group_vars/all/vault.yml.example $(VAULTF)
	@echo "Created $(VAULTF) — fill it, then: make vault-encrypt ENV=$(ENV)"

vault-edit:  ## Edit the encrypted vault for ENV
	ansible-vault edit $(VAULTF)

vault-view:  ## View the encrypted vault for ENV
	ansible-vault view $(VAULTF)

vault-encrypt:  ## Encrypt ENV vault.yml
	ansible-vault encrypt $(VAULTF)

vault-decrypt:  ## Decrypt ENV vault.yml (careful — plaintext on disk)
	ansible-vault decrypt $(VAULTF)

vault-rekey:  ## Change the vault password for ENV
	ansible-vault rekey $(VAULTF)

sparse:  ## Add paths to a sparse checkout: make sparse PATHS="roles/components/nginx"
	git sparse-checkout add $(PATHS)

lab-up:  ## Build + start the local EL test containers (LAB_PLATFORM=linux/arm64|amd64)
	$(LAB_COMPOSE) up -d --build
	@echo "Lab up on $(LAB_PLATFORM). Install collections once: make deps"

lab-down:  ## Stop and remove the lab containers
	$(LAB_COMPOSE) down -v

lab-ps:  ## Show lab container status
	$(LAB_COMPOSE) ps

lab-shell:  ## Shell into a lab container: make lab-shell C=rocky8
	docker exec -it $(C) bash

lab-syntax:  ## Syntax-check PB against the lab inventory
	ansible-playbook -i $(LAB_INV) $(PLAY) --syntax-check

lab-check:  ## Structural dry-run (--check --diff) against the lab — fast, arm64-friendly
	ansible-playbook -i $(LAB_INV) $(PLAY) --check --diff $(TAGARG)

lab-run:  ## Full real run against the lab (e.g. make lab-run PB=alpha-notes)
	ansible-playbook -i $(LAB_INV) $(PLAY) $(TAGARG)

lab-idem:  ## Idempotence: run twice; the 2nd run should report changed=0
	ansible-playbook -i $(LAB_INV) $(PLAY) $(TAGARG)
	ansible-playbook -i $(LAB_INV) $(PLAY) $(TAGARG) | tee /tmp/lab-idem.txt; \
	  grep -qE 'changed=0 .*failed=0' /tmp/lab-idem.txt && echo "IDEMPOTENT ✓" || echo "NOT idempotent ✗"

sparse-role:  ## Sparse-checkout ONE role + its deps: make sparse-role ROLE=notes-api [ENV=alpha-prod]
	@test -n "$(ROLE)" || { echo "Usage: make sparse-role ROLE=<name> [ENV=$(ENV)]"; exit 2; }
	@role='$(ROLE)'; base="inventory/$(ENV) playbooks"; \
	case "$$role" in \
	  nginx|postgres) paths="roles/components/$$role";; \
	  hello-web) paths="roles/services/hello-web roles/components/nginx";; \
	  notes-api) paths="roles/services/notes-api roles/components/postgres roles/components/nginx";; \
	  *) echo "Unknown role: $$role"; echo "See docs/sparse-checkout.md."; exit 2;; \
	esac; \
	echo "sparse-checkout set -> $$base $$paths"; \
	git sparse-checkout init --cone 2>/dev/null || true; \
	git sparse-checkout set $$base $$paths; \
	git checkout 2>/dev/null || true; \
	echo "Done. Remember to vendor local blobs (JARs, RPMs, FS sounds) if this role needs them."
