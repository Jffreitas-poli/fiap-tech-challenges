# Plano de PRs — Infra da Fase 3

A infra da Fase 3 (Terraform + workflows + GitOps) foi entregue em **6 PRs
pequenos**, empilhados linearmente sobre a `main`
(`main ← PR1 ← PR2 ← PR3 ← PR4 ← PR5 ← PR6`). Cada PR mostra no diff só os
seus próprios arquivos (paths disjuntos, sem conflito) e deve ser mergeado na
ordem **1 → 6**. Ao mergear o PR N, o GitHub re-aponta a base do PR N+1 para a
`main` automaticamente.

**Repositório:** `github.com/NyEstevo/fiap-tech-challenges` · **Base:** `main`
· **Títulos:** Conventional Commits.

Nenhum merge aplica nada na AWS — o primeiro `terraform apply` é manual, ver
`fase-3/infra/PASSO-A-PASSO.md`.

| # | Branch | Base | Título |
|---|---|---|---|
| 1 | `chore/fase3-tf-bootstrap` | `main` | `chore(infra): bootstrap do Terraform state + gitignore` |
| 2 | `feat/fase3-tf-modules` | PR 1 | `feat(infra): módulos Terraform reutilizáveis` |
| 3 | `feat/fase3-gitops` | PR 2 | `feat(gitops): estrutura ArgoCD (app-of-apps + kustomizations)` |
| 4 | `feat/fase3-tf-envs` | PR 3 | `feat(infra): composição do ambiente lab + scaffolding prod` |
| 5 | `ci/fase3-infra-workflows` | PR 4 | `ci(infra): workflows tf-plan / tf-apply / tf-destroy` |
| 6 | `docs/fase3-infra-runbook` | PR 5 | `docs(infra): runbook e passo a passo da Fase 3` |

---

## PR 1 — bootstrap do Terraform state + gitignore

**Arquivos:** `.gitignore` (bloco Terraform), `fase-3/infra/terraform/.tflint.hcl`,
`fase-3/infra/bootstrap/**`

Cria (quando aplicado à parte, fora do CI) o bucket
`s3://tc-fiap-tfstate-361075236043` e a tabela de lock `tc-fiap-tflock`, ambos
com `prevent_destroy`. State local (é o que cria o backend).

**Validação:** `cd fase-3/infra/bootstrap && terraform fmt -check && terraform init -backend=false && terraform validate`
**Seguro no merge:** sim — nada referencia este diretório.

## PR 2 — módulos Terraform reutilizáveis

**Arquivos:** `fase-3/infra/terraform/modules/**` — `networking`, `eks`, `ecr`,
`rds`, `elasticache`, `sqs`, `dynamodb`, `addons`, `iam_oidc_github`
(este último só como referência — não aplicável no AWS Academy).

9 módulos parametrizáveis; ainda não instanciados por ninguém. `eks` e `sqs`
documentam no código a ausência de IAM/IRSA sob o Academy.

**Validação:** `cd fase-3/infra/terraform && terraform fmt -check -recursive`;
`terraform init -backend=false && terraform validate` por módulo.
**Seguro no merge:** sim.

## PR 3 — estrutura ArgoCD

**Arquivos:** `fase-3/gitops/**` — `root-app.yaml` (app-of-apps),
`apps/{auth,flag,targeting,evaluation,analytics}.yaml`,
`manifests/<svc>/kustomization.yaml`, `README.md`

Os overlays Kustomize reaproveitam `fase-2/*/k8s/` (sem duplicar) e **omitem
`secrets.yaml`** (credenciais em base64). `images[].newTag` é o ponto que o CI
de app atualiza. `root-app.yaml` é aplicado pelo Terraform no PR 4.

**Validação:** parse de todos os YAML; opcional `kustomize build fase-3/gitops/manifests/auth --load-restrictor LoadRestrictionsNone`.
**Seguro no merge:** sim — YAML inerte.

## PR 4 — composição do ambiente lab + scaffolding prod

**Arquivos:** `fase-3/infra/terraform/envs/lab/**` (backend, providers,
variables, main, outputs, `terraform.tfvars[.example]`, `.terraform.lock.hcl`),
`fase-3/infra/terraform/envs/prod/**` (só scaffolding: backend key própria +
`terraform.tfvars.example` + README)

Amarra os módulos (PR 2) com os valores da conta e referencia
`fase-3/gitops/root-app.yaml` (PR 3) via `kubernetes_manifest.root_app`.

**Validação:** `cd fase-3/infra/terraform/envs/lab && terraform init -backend=false -input=false && terraform validate`
**Seguro no merge:** sim — não há workflow ainda (entra no PR 5).

## PR 5 — workflows tf-plan / tf-apply / tf-destroy

**Arquivos:** `.github/workflows/infra-tf-plan.yml`,
`.github/workflows/infra-tf-apply.yml`, `.github/workflows/infra-tf-destroy.yml`

**Pré-requisitos antes de mergear** (senão o 1º check de plan falha):

1. PR 1 aplicado de fato (bucket + tabela de lock existem) — Passo 2 do runbook.
2. Secrets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN`
   no repositório — Passo 3.1.
3. Environments `lab` e `prod` com **Required reviewers** — Passo 3.3.

**Comportamento no merge:**

- `infra-tf-plan` roda **neste próprio PR** (o path `.github/workflows/infra-tf-*.yml`
  casa o trigger). Com os pré-requisitos prontos, comenta o `plan` inicial
  (que vai propor criar toda a infra); sem eles, falha com `ExpiredToken`/backend
  — esperado.
- `infra-tf-apply` dispara em push na `main` com mudança em
  `fase-3/infra/terraform/**`. **Mergear só os workflows não casa esse path**,
  então nenhum apply automático acontece.

**Validação:** parse dos 3 YAML; opcional `actionlint`.

## PR 6 — runbook e passo a passo

**Arquivos:** `fase-3/infra/README.md`, `fase-3/infra/PASSO-A-PASSO.md`,
`fase-3/PLANO-DE-PRS.md` (este arquivo)

Documentação pura; fecha o stack.

---

## Ordem de merge

1 → 2 → 3 → 4 → 5 → 6, pelo GitHub. A cada merge, o "Update branch" / retarget
de base do PR seguinte é automático. Antes de mergear o **PR 5**, garanta os
3 pré-requisitos listados nele.
