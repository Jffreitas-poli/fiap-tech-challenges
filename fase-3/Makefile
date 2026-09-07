.PHONY: tools render-baseline render-diff render-accept lint lint-terraform lint-actions \
	lint-gitops lint-registry lint-secrets lint-structure plan selftest

# Path com ferramentas localmente instaladas
export PATH := $(HOME)/.local/bin:/snap/bin:$(PATH)

# ============================================================================
# Ancoragem: todos os caminhos derivam da localizacao deste Makefile, nunca do
# PWD. Rodar `make` de qualquer subdiretorio (ou com `-f` por caminho absoluto)
# grava golden/artefatos no lugar certo e nao depende de `git`.
# `ROOT` / `FASE3` sao sobrescriviveis na linha de comando (usado pelo `selftest`).
# ============================================================================
THIS_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))
FASE3         ?= $(patsubst %/,%,$(dir $(THIS_MAKEFILE)))
ROOT          ?= $(patsubst %/,%,$(dir $(FASE3)))

GITOPS_DIR      = $(FASE3)/gitops
MANIFESTS_DIR   = $(GITOPS_DIR)/manifests
RENDER_DIR      = $(GITOPS_DIR)/.render
SERVICES_YAML   = $(FASE3)/services.yaml
TF_DIR          = $(FASE3)/infra/terraform
MAKEFILE_PATH   = $(THIS_MAKEFILE)
WORKFLOWS_DIR   = $(ROOT)/.github/workflows
ACTIONS_DIR     = $(ROOT)/.github/actions

KUSTOMIZE_FLAGS := --load-restrictor LoadRestrictionsNone

# Overlays sincronizados pelo ArgoCD
OVERLAYS         := auth flag targeting evaluation analytics platform ingress
# Overlays que sao servico (platform e ingress nao sao) -- alvo do invariante 5f
SERVICE_OVERLAYS := auth flag targeting evaluation analytics

# Registry esperado do ambiente (lab)
REGISTRY := 361075236043.dkr.ecr.us-east-1.amazonaws.com/tech-challenge

# Variáveis derived
SVC_COUNT := $(shell yq '.services | length' "$(FASE3)/services.yaml" 2>/dev/null || echo "0")

# ============================================================================
# TOOLS: instalar e verificar ferramentas
# ============================================================================
tools:
	@set -e; \
	missing=""; \
	for tool in kustomize kubeconform checkov trivy gitleaks yq; do \
		if ! (command -v $$tool &>/dev/null || [ -x "/snap/bin/$$tool" ]); then \
			missing="$$missing $$tool"; \
		fi; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "erro: ferramentas ausentes:$$missing" >&2; \
		exit 1; \
	fi; \
	echo "ok: todas as ferramentas estão disponíveis"

# ============================================================================
# RENDER-BASELINE: captura o estado atual renderizado (normalizado)
# ============================================================================
render-baseline:
	@set -e; \
	mkdir -p "$(RENDER_DIR)"; \
	for overlay in $(OVERLAYS); do \
		outfile="$(RENDER_DIR)/$${overlay}.yaml"; \
		kustomize build "$(MANIFESTS_DIR)/$${overlay}" $(KUSTOMIZE_FLAGS) \
			| yq -P '.' \
			> "$$outfile"; \
		echo "render-baseline: $$overlay -> $$outfile"; \
	done; \
	echo "render-baseline: $(RENDER_DIR) atualizado"

# ============================================================================
# RENDER-DIFF: compara renderização atual com o golden versionado.
# Le um artefato (o golden). Ausencia ou golden vazio e FALHA, nunca sucesso
# silencioso: nao regenera nada por baixo do usuario.
# ============================================================================
render-diff:
	@set -e; \
	if [ ! -d "$(RENDER_DIR)" ]; then \
		echo "render-diff: golden ausente em $(RENDER_DIR); rode 'make render-baseline'" >&2; \
		exit 1; \
	fi; \
	has_diff=0; \
	for overlay in $(OVERLAYS); do \
		baseline="$(RENDER_DIR)/$${overlay}.yaml"; \
		if [ ! -s "$$baseline" ]; then \
			echo "render-diff: golden ausente ou vazio: $$baseline" >&2; \
			exit 1; \
		fi; \
		current=$$(mktemp); \
		kustomize build "$(MANIFESTS_DIR)/$${overlay}" $(KUSTOMIZE_FLAGS) \
			| yq -P '.' \
			> "$$current"; \
		if ! diff -u "$$baseline" "$$current"; then \
			has_diff=1; \
		fi; \
		rm -f "$$current"; \
	done; \
	exit $$has_diff

# ============================================================================
# RENDER-ACCEPT: promove render atual a novo baseline (uso explícito)
# ============================================================================
render-accept: render-baseline
	@echo "render-accept: baseline atualizado"

# ============================================================================
# LINT-TERRAFORM
# ============================================================================
lint-terraform:
	@set -e; \
	[ -d "$(TF_DIR)" ] || { echo "lint-terraform: $(TF_DIR) não existe; pulando"; exit 0; }; \
	\
	echo "lint-terraform: terraform fmt..."; \
	terraform fmt -check -recursive "$(TF_DIR)"; \
	\
	echo "lint-terraform: terraform validate (envs + modules)..."; \
	for dir in "$(TF_DIR)"/envs/lab "$(TF_DIR)"/envs/prod "$(TF_DIR)"/modules/*; do \
		[ -d "$$dir" ] || continue; \
		ls "$$dir"/*.tf >/dev/null 2>&1 || continue; \
		echo "  -> $$dir"; \
		terraform -chdir="$$dir" init -backend=false -input=false -no-color >/dev/null; \
		terraform -chdir="$$dir" validate -no-color; \
	done; \
	\
	echo "lint-terraform: tflint..."; \
	tflint --chdir="$(TF_DIR)" --init >/dev/null; \
	tflint --chdir="$(TF_DIR)" --recursive; \
	\
	echo "lint-terraform: checkov..."; \
	checkov -d "$(TF_DIR)" \
		--config-file "$(TF_DIR)/.checkov.yaml"; \
	\
	echo "lint-terraform: trivy..."; \
	trivy config "$(TF_DIR)" \
		--ignorefile "$(TF_DIR)/.trivyignore" \
		--severity CRITICAL --exit-code 1

# ============================================================================
# LINT-ACTIONS
# ============================================================================
lint-actions:
	@set -e; \
	[ -d "$(WORKFLOWS_DIR)" ] || { echo "lint-actions: $(WORKFLOWS_DIR) não existe; pulando"; exit 0; }; \
	\
	echo "lint-actions: actionlint..."; \
	actionlint "$(WORKFLOWS_DIR)"/*.yml "$(ACTIONS_DIR)"/*/action.yml 2>&1 || { \
		echo "lint-actions: actionlint falhou" >&2; \
		exit 1; \
	}

# ============================================================================
# LINT-GITOPS
# ============================================================================
lint-gitops:
	@set -e; \
	for overlay in $(OVERLAYS); do \
		echo "lint-gitops: kubeconform $${overlay}..."; \
		kustomize build "$(MANIFESTS_DIR)/$${overlay}" $(KUSTOMIZE_FLAGS) \
			| kubeconform -strict -ignore-missing-schemas -output json 2>&1 \
			|| { echo "lint-gitops: kubeconform falhou para $${overlay}" >&2; exit 1; }; \
	done; \
	\
	echo "lint-gitops: verificando Secrets com data: base64..."; \
	for overlay in $(OVERLAYS); do \
		if kustomize build "$(MANIFESTS_DIR)/$${overlay}" $(KUSTOMIZE_FLAGS) \
			| grep -E '^\s+data:' -A 100 \
			| grep -q 'kind: Secret'; then \
			echo "lint-gitops: Secret com data: base64 encontrado" >&2; \
			exit 1; \
		fi; \
	done; \
	\
	echo "lint-gitops: invariante 5f (exatamente 1 campo images: por servico)..."; \
	for svc in $(SERVICE_OVERLAYS); do \
		k="$(MANIFESTS_DIR)/$${svc}/kustomization.yaml"; \
		if [ ! -f "$$k" ]; then \
			echo "lint-gitops: 5f falhou (kustomization ausente para $$svc)" >&2; \
			exit 1; \
		fi; \
		n=$$(grep -c '^images:' "$$k" || true); \
		if [ "$$n" -ne 1 ]; then \
			echo "lint-gitops: 5f falhou ($$svc: $$n campos images:, esperado 1)" >&2; \
			exit 1; \
		fi; \
	done

# ============================================================================
# LINT-REGISTRY
# Le um artefato (allowed-images.txt). Ausencia OU arquivo vazio e FALHA.
# ============================================================================
lint-registry:
	@set -e; \
	allow="$(RENDER_DIR)/allowed-images.txt"; \
	if [ ! -s "$$allow" ]; then \
		echo "lint-registry: $$allow não existe ou está vazio" >&2; \
		exit 1; \
	fi; \
	\
	for overlay in $(OVERLAYS); do \
		echo "lint-registry: verificando $${overlay}..."; \
		kustomize build "$(MANIFESTS_DIR)/$${overlay}" $(KUSTOMIZE_FLAGS) \
			| grep -oE '^\s*(- )?image:\s*\S+' | awk '{print $$NF}' | sort -u \
			| while read -r img; do \
				case "$$img" in \
					$(REGISTRY)/*) \
						;; \
					*) \
						if ! grep -qxF "$$img" "$$allow"; then \
							echo "lint-registry: imagem não autorizada: $$img" >&2; \
							exit 1; \
						fi; \
						;; \
				esac; \
			done || exit 1; \
	done

# ============================================================================
# LINT-SECRETS
# ============================================================================
lint-secrets:
	@set -e; \
	echo "lint-secrets: gitleaks detect..."; \
	gitleaks detect --no-banner --source "$(ROOT)" || { \
		echo "lint-secrets: gitleaks detectou segredos" >&2; \
		exit 1; \
	}

# ============================================================================
# LINT-STRUCTURE
# ============================================================================
lint-structure:
	@set -e; \
	\
	echo "lint-structure: invariante 3d (Makefile com alvos do contrato)..."; \
	for target in tools lint lint-terraform lint-actions lint-gitops lint-registry render-diff; do \
		if ! grep -qE "^$${target}:" "$(MAKEFILE_PATH)"; then \
			echo "lint-structure: 3d falhou (alvo $$target não encontrado)" >&2; \
			exit 1; \
		fi; \
	done; \
	\
	[ ! -d "$(TF_DIR)" ] && { echo "lint-structure: $(TF_DIR) não existe; pulando 3a/3b/3c"; exit 0; }; \
	\
	echo "lint-structure: invariante 3a (nenhum .tf com nome de serviço)..."; \
	if find "$(TF_DIR)" -name '*.tf' 2>/dev/null \
		| grep -E '/(auth|flag|targeting|evaluation|analytics)[-_.]'; then \
		echo "lint-structure: 3a falhou" >&2; \
		exit 1; \
	fi; \
	\
	echo "lint-structure: invariante 3b (module rds/ecr uma vez por env)..."; \
	rds_count=$$(grep -rhcE '^\s*module\s+"rds"\s*\{' "$(TF_DIR)"/envs 2>/dev/null | awk '{s+=$$1} END{print s+0}'); \
	if [ "$$rds_count" -ne 2 ]; then \
		echo "lint-structure: 3b falhou (rds_count=$$rds_count, esperado 2)" >&2; \
		exit 1; \
	fi; \
	ecr_count=$$(grep -rhcE '^\s*module\s+"ecr"\s*\{' "$(TF_DIR)"/envs 2>/dev/null | awk '{s+=$$1} END{print s+0}'); \
	if [ "$$ecr_count" -ne 2 ]; then \
		echo "lint-structure: 3b falhou (ecr_count=$$ecr_count, esperado 2)" >&2; \
		exit 1; \
	fi; \
	\
	echo "lint-structure: invariante 3c (nº de repos ECR == SVC_COUNT + MIG)..."; \
	mig=$$(yq '[.services[] | select(.db.migrate == "dedicated")] | length' "$(SERVICES_YAML)" 2>/dev/null || echo "0"); \
	expected=$$(($(SVC_COUNT) + mig)); \
	for env in lab prod; do \
		if [ ! -f "$(TF_DIR)/envs/$$env/main.tf" ]; then continue; fi; \
		ecr_repos=$$(grep -c 'tech-challenge/' "$(TF_DIR)/envs/$$env/main.tf" 2>/dev/null || echo "0"); \
		if [ "$$ecr_repos" -ne "$$expected" ]; then \
			echo "lint-structure: 3c falhou ($$env: $$ecr_repos repos, esperado $$expected)" >&2; \
			exit 1; \
		fi; \
	done

# ============================================================================
# LINT: agregador (todos os lint-*)
# ============================================================================
lint: lint-terraform lint-actions lint-gitops lint-registry lint-secrets
	@echo "lint: ok"

# ============================================================================
# PLAN: terraform plan JSON filtrado
# ============================================================================
plan:
	@set -e; \
	if [ -z "$(ENV)" ]; then \
		echo "erro: ENV não definido (use: make plan ENV=lab|prod)" >&2; \
		exit 1; \
	fi; \
	[ -d "$(TF_DIR)" ] || { echo "plan: $(TF_DIR) não existe; pulando"; exit 0; }; \
	\
	echo "plan: terraform plan para $(ENV)..." >&2; \
	terraform -chdir="$(TF_DIR)/envs/$(ENV)" plan -json -input=false -lock=false 2>&1 \
		| jq -r 'select(.type == "planned_change") | "\(.change.action // "?")\t\(.change.resource.addr)"'

# ============================================================================
# SELFTEST: prova que cada portao MORDE.
# Para cada portao, injeta num clone temporario um defeito que ele DEVE pegar
# e afirma que o alvo correspondente sai != 0. Um portao que passa nesse
# defeito e um portao inexistente.
# ============================================================================
selftest:
	@set -u; \
	src_root="$(ROOT)"; \
	src_fase3="$(FASE3)"; \
	src_gitops="$(GITOPS_DIR)"; \
	src_render="$(RENDER_DIR)"; \
	src_services="$(SERVICES_YAML)"; \
	src_makefile="$(MAKEFILE_PATH)"; \
	fails=0; \
	green()  { printf '  \033[32mOK  \033[0m %s\n' "$$1"; }; \
	red()    { printf '  \033[31mFAIL\033[0m %s\n' "$$1"; fails=$$((fails+1)); }; \
	setup() { \
		w=$$(mktemp -d); \
		mkdir -p "$$w/fase-3"; \
		cp -r "$$src_root/fase-2" "$$w/fase-2"; \
		cp -r "$$src_gitops" "$$w/fase-3/gitops"; \
		cp "$$src_services" "$$w/fase-3/services.yaml"; \
		cp "$$src_makefile" "$$w/fase-3/Makefile"; \
		for d in "$$src_fase3"/*/k8s; do \
			[ -d "$$d" ] || continue; \
			svc=$$(basename "$$(dirname "$$d")"); \
			mkdir -p "$$w/fase-3/$$svc"; \
			cp -r "$$d" "$$w/fase-3/$$svc/k8s"; \
		done; \
		printf '%s' "$$w"; \
	}; \
	run() { $(MAKE) --no-print-directory -C "$$1/fase-3" -f "$$1/fase-3/Makefile" ROOT="$$1" "$$2" >/dev/null 2>&1; }; \
	expect_pass() { if run "$$1" "$$2"; then green "$$3"; else red "$$3 (esperava exit 0, veio != 0)"; fi; }; \
	expect_fail() { if run "$$1" "$$2"; then red "$$3 (portao NAO mordeu: exit 0)"; else green "$$3"; fi; }; \
	echo "selftest: clone de controle (todos os portoes verdes num estado limpo)"; \
	w=$$(setup); \
	expect_pass "$$w" render-diff    "controle: render-diff"; \
	expect_pass "$$w" lint-registry  "controle: lint-registry"; \
	expect_pass "$$w" lint-gitops    "controle: lint-gitops"; \
	rm -rf "$$w"; \
	echo "selftest: PORTAO render-diff"; \
	w=$$(setup); rm -rf "$$w/fase-3/gitops/.render"; \
	expect_fail "$$w" render-diff "golden ausente (diretorio .render/ removido)"; \
	rm -rf "$$w"; \
	w=$$(setup); : > "$$w/fase-3/gitops/.render/auth.yaml"; \
	expect_fail "$$w" render-diff "golden vazio (auth.yaml truncado)"; \
	rm -rf "$$w"; \
	w=$$(setup); rm -f "$$w/fase-3/gitops/.render/flag.yaml"; \
	expect_fail "$$w" render-diff "golden de um overlay faltando (flag.yaml)"; \
	rm -rf "$$w"; \
	w=$$(setup); \
	sed -i 's#- ../../../../fase-2/auth-service/k8s/service.yaml#&\n- ../../../../fase-2/ingress.yaml#' \
		"$$w/fase-3/gitops/manifests/auth/kustomization.yaml"; \
	expect_fail "$$w" render-diff "../fase-2/ a mais no overlay auth (drift de render)"; \
	rm -rf "$$w"; \
	echo "selftest: PORTAO lint-registry"; \
	w=$$(setup); rm -f "$$w/fase-3/gitops/.render/allowed-images.txt"; \
	expect_fail "$$w" lint-registry "allowed-images.txt ausente"; \
	rm -rf "$$w"; \
	w=$$(setup); : > "$$w/fase-3/gitops/.render/allowed-images.txt"; \
	expect_fail "$$w" lint-registry "allowed-images.txt vazio"; \
	rm -rf "$$w"; \
	w=$$(setup); \
	sed -i 's#newName: 361075236043.dkr.ecr.us-east-1.amazonaws.com/tech-challenge/flag-image#newName: evil.example.com/tech-challenge/flag-image#' \
		"$$w/fase-3/gitops/manifests/flag/kustomization.yaml"; \
	expect_fail "$$w" lint-registry "imagem de registry nao autorizado (evil.example.com)"; \
	rm -rf "$$w"; \
	echo "selftest: PORTAO lint-gitops (5f) + render-diff"; \
	w=$$(setup); \
	printf 'images:\n- name: 047719652987.dkr.ecr.us-east-2.amazonaws.com/tech-challenge/auth-image\n  newName: 361075236043.dkr.ecr.us-east-1.amazonaws.com/tech-challenge/auth-image\n  newTag: deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\n' \
		>> "$$w/fase-3/gitops/manifests/auth/kustomization.yaml"; \
	expect_fail "$$w" lint-gitops "kustomization com images: duplicado (5f)"; \
	expect_fail "$$w" render-diff "kustomization com images: duplicado (drift de render)"; \
	rm -rf "$$w"; \
	echo; \
	if [ "$$fails" -ne 0 ]; then \
		echo "selftest: $$fails assercao(oes) FALHARAM" >&2; \
		exit 1; \
	fi; \
	echo "selftest: todos os portoes mordem"
