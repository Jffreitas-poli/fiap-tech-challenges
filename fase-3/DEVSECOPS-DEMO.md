# DevSecOps — vulnerabilidade proposital barrando o pipeline

Requisito do checklist: *"Adicione uma dependência com vulnerabilidade
conhecida e mostre o pipeline falhando."*

## Como reproduzir

Branch de demonstração (criada a partir da `main`, **nunca mergeada**):

```bash
git checkout main
git checkout -b demo/devsecops-vuln-block
```

Adicione uma dependência com CVE **CRÍTICO e com correção disponível** em
`fase-2/flags-service/requirements.txt`:

```diff
  SQLAlchemy==2.0.32
+ PyYAML==5.3.1        # CVE-2020-14343 (CRITICAL) - RCE via yaml.full_load; corrigido em 5.4
```

```bash
git commit -am "demo: dependencia com CVE critico (nao mergear)"
git push -u origin demo/devsecops-vuln-block
```

Abra um PR de `demo/devsecops-vuln-block` para `lab`.

## O que acontece

O push/PR casa o path `fase-2/flags-service/**` e dispara **`ci-flags.yml`** →
`_reusable-ci-service.yml`:

1. `build-and-test` — passa
2. `lint` — passa
3. **`security-sast-sca` — FALHA** no step *"trivy fs (SCA)"*:

   ```
   fase-2/flags-service/requirements.txt (pip)
   ==========================================
   Total: 1 (CRITICAL: 1)

   ┌─────────┬────────────────┬──────────┬────────┬───────────────────┬───────────────┐
   │ Library │ Vulnerability  │ Severity │ Status │ Installed Version │ Fixed Version │
   ├─────────┼────────────────┼──────────┼────────┼───────────────────┼───────────────┤
   │ PyYAML  │ CVE-2020-14343 │ CRITICAL │ fixed  │ 5.3.1             │ 5.4           │
   └─────────┴────────────────┴──────────┴────────┴───────────────────┴───────────────┘
   ```

   O step roda com `severity: CRITICAL` + `exit-code: 1`, então o job termina
   vermelho.
4. `docker-build-scan-push` — **não executa** (`needs: security-sast-sca`).
5. `gitops-update` — **não executa**. Nenhuma imagem vai para o ECR, nenhum
   bump chega na branch `lab`, o ArgoCD não sincroniza nada.

## Como o pipeline "cura"

Trocar por `PyYAML==5.4.1` (ou remover a dependência) → `trivy fs` volta a
passar → os estágios seguintes destravam. Fim da demonstração; a branch
`demo/devsecops-vuln-block` é descartada.

## Outras camadas de bloqueio equivalentes

| Camada | Ferramenta | Onde |
|---|---|---|
| SCA (dependências) | `trivy fs --severity CRITICAL --exit-code 1` | `security-sast-sca` |
| SAST (código Go) | `gosec -severity high` | `security-sast-sca` |
| SAST (código Python) | `bandit -ll -ii` | `security-sast-sca` |
| Imagem de container | `trivy image --severity CRITICAL --exit-code 1` | `docker-build-scan-push` (antes do push) |
| IaC | `checkov` (soft-fail:false) + `trivy config --severity CRITICAL` | `infra-tf-plan` / `infra-tf-apply` |
