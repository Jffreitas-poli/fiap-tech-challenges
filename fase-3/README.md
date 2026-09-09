<div align="center">
  <br/>
  <hr style="border: none; border-top: 1px solid #ED145B; width: 100%; margin: 0 auto"/>
</div>

![/.github/LOGO-FIAP.png](/.github/LOGO-FIAP.png)

# Tech Challenge - Objetivos da Fase 3

Na Fase 2, evoluímos o Toggle Master de monolito para uma arquitetura de microsserviços containerizada em Kubernetes. No entanto, a operação continuava manual: deploys feitos via `kubectl apply` a partir de máquinas locais, credenciais de banco em arquivos de texto e ambientes recriados manualmente pelo console AWS. Na Fase 3, o objetivo é eliminar esse trabalho manual: "se não está no código, não existe".

Automatizamos toda a infraestrutura e o ciclo de vida dos 5 microsserviços do ToggleMaster (`auth`, `flag`, `targeting`, `evaluation`, `analytics`) com **Infraestrutura como Código (Terraform)**, **pipelines de CI/DevSecOps** e **entrega contínua via GitOps com ArgoCD**.

## Entregáveis da Fase 3

1. **Vídeo de Demonstração (até 20 minutos):** [link do vídeo]

2. **Documentação Separada por Tópicos:**

- [O Problema: Operação Insustentável](#o-problema-operação-insustentável);
- [Infraestrutura como Código (Terraform)](#infraestrutura-como-código-terraform);
- [Backend Remoto do Terraform State](#backend-remoto-do-terraform-state);
- [Pipeline de CI & DevSecOps](#pipeline-de-ci--devsecops);
- [Entrega Contínua (CD) & GitOps](#entrega-contínua-cd--gitops);
- [Dificuldades Encontradas](#dificuldades-encontradas);
- [Estimativa de Custos](#estimativa-de-custos);
- [Diagrama de Arquitetura](#diagrama-de-arquitetura);
- [Integrantes do Grupo](#integrantes-do-grupo);

3. **Código Fonte no Repositório:**

- Código Terraform completo, organizado em módulos.
- Workflows de CI/CD (GitHub Actions) com os passos de DevSecOps.
- Manifestos Kubernetes ajustados para GitOps.

4. **Relatório de Entrega (.PDF ou .txt):** nomes dos participantes, link da documentação e do vídeo, resumo de desafios/decisões e print da estimativa de custos da AWS.

5. **Integrantes do Grupo**:

- [Aline Estevo da Silva](https://www.linkedin.com/in/aline-estevo)
- [Thiago de Melo Macedo](https://www.linkedin.com/in/thiago-melo-macedo)
- [Jefferson Fernandes de Freitas](#)
- [Vinicius Jorge de Oliveira](#)

> **Importante — Ambiente de Nuvem (Terraform & IAM):** assim como nas fases anteriores, trabalhamos sob as restrições do AWS Academy: o código Terraform **não cria Roles ou Policies de IAM**. O cluster EKS e os Node Groups utilizam a `LabRole` existente, importada via `data source` do Terraform.

## O Problema: Operação Insustentável

A arquitetura de microsserviços aprovada na Fase 2 trouxe quatro problemas operacionais que motivam a Fase 3:

- **Deploys manuais e conflitantes:** desenvolvedores rodando `kubectl apply` a partir de máquinas locais, sem fonte única de verdade, gerando conflitos de versão entre ambientes.
- **Credenciais inseguras:** credenciais de banco de dados trafegando em arquivos de texto sem criptografia ou gestão de secrets.
- **Vulnerabilidades não detectadas:** uma vulnerabilidade em uma biblioteca Go chegou à produção sem ser barrada em nenhuma etapa do processo.
- **Ambientes não reprodutíveis:** recriar o ambiente de homologação levava dias, por ter sido provisionado manualmente no console AWS.

A resposta a esses quatro pontos é, respectivamente: GitOps (fonte única de verdade), DevSecOps com secrets gerenciados, security scanning obrigatório no pipeline, e Infraestrutura como Código.

## Infraestrutura como Código (Terraform)

Toda a infraestrutura que era provisionada manualmente na Fase 2 foi substituída por um projeto Terraform organizado em módulos, provisionando:

1. **Networking:** VPC, Subnets públicas e privadas, Internet Gateway e Route Tables.
2. **Cluster EKS:** cluster Kubernetes e Node Groups, associados à `LabRole` do AWS Academy.
3. **Bancos de Dados:**
   - 3 instâncias RDS (PostgreSQL) — uma para cada serviço com dados relacionais (`auth-service`, `flags-service`, `targeting-service`), preservando o isolamento de *database-per-service* já adotado na Fase 2.
   - 1 Cluster ElastiCache (Redis).
   - 1 tabela DynamoDB (`ToggleMasterAnalytics`), usada pelo `analytics-service`.
4. **Mensageria:** 1 fila SQS, consumida pelo `analytics-service` e usada como gatilho de escalabilidade do KEDA.
5. **Repositórios:** 5 repositórios ECR (um por microsserviço), provisionados via Terraform.

Árvore real do Terraform (`fase-3/infra/`):

```
infra/
├── bootstrap/                 # state local; roda 1x fora do CI
│   ├── (lab)  main/variables/outputs.tf     # bucket S3 + lock DynamoDB
│   └── prod/  main/variables/outputs.tf     # bucket S3 + lock + OIDC + IAM (conta pessoal)
└── terraform/
    ├── modules/
    │   ├── networking/        # VPC, subnets pub/priv, IGW, NAT, route tables
    │   ├── eks/               # cluster + node group (LabRole no lab; roles próprias no prod)
    │   ├── rds/               # instância PostgreSQL + SG + secret (for_each: auth/flag/targeting)
    │   ├── elasticache/       # replication group Redis
    │   ├── dynamodb/          # tabela de eventos do analytics
    │   ├── sqs/               # fila + DLQ (SSE gerenciado)
    │   ├── ecr/               # repositórios (for_each), scan-on-push, lifecycle
    │   ├── addons/            # helm_release: metrics-server, ingress-nginx, keda, external-secrets, argocd
    │   └── iam_oidc_github/   # OIDC provider + role (usado só pelo bootstrap/prod)
    ├── envs/
    │   ├── lab/               # APLICADO — LabRole, 2 AZs, single-AZ RDS
    │   └── prod/              # código pronto, NÃO aplicado — HA, IAM próprio, OIDC
    ├── .checkov.yaml          # gate bloqueante (soft-fail:false) + baseline Academy
    └── .tflint.hcl
```

Regras seguidas: `required_providers` fixados com `~>`; `for_each` onde a chave
importa (serviços RDS, repos ECR); `locals` para transformações; blocos
`validation {}` nos inputs críticos dos módulos; outputs sensíveis com
`sensitive = true`; `tags`/`default_tags` padronizadas via `local.common_tags`.

## Backend Remoto do Terraform State

O `terraform.tfstate` não é mantido localmente. O backend remoto é um **Bucket
S3** (`tc-fiap-tfstate-047719652987`, versionado e com encryption), com
**state locking via tabela DynamoDB** (`tc-fiap-tflock`) — `use_lockfile` (lock
nativo no S3) exige Terraform ≥ 1.10 e o projeto fixa `1.9.8`; a migração para
`use_lockfile` está documentada como passo futuro. O lock evita aplicações
concorrentes e perda de estado entre máquinas/pipelines. `envs/lab` e `envs/prod`
usam chaves distintas (`fase-3/lab/…` e `fase-3/prod/…`) no mesmo bucket (lab) ou
em bucket próprio (prod, criado por `bootstrap/prod`).

## Pipeline de CI & DevSecOps

Cada um dos 5 microsserviços tem seu próprio workflow de CI
(`.github/workflows/ci-<svc>.yml`), disparado em Pull Requests e em pushes para
`lab`/`main` que tocam `fase-2/<svc>-service/**`. Todos chamam o workflow
reutilizável **`_reusable-ci-service.yml`** (parametrizado por `service_name`,
`service_language`, `working_directory`). A autenticação AWS é a composite
action **`.github/actions/aws-auth`** (lab → chaves estáticas de sessão;
`main` → OIDC). Estágios sequenciais — cada job depende do anterior:

1. **`build-and-test`:** Go → `go build` + `go vet` + `go test -race -cover`;
   Python → `pip install` + `pytest --cov`. Cobertura publicada como artifact.
2. **`lint` (bloqueante):** Go → `golangci-lint` v2 (config `.golangci.yml` por
   serviço); Python → `ruff check` + `ruff format --check` (`fase-2/.ruff.toml`).
3. **`security-sast-sca` (bloqueante em CRÍTICO):**
   - **SCA:** `trivy fs --severity CRITICAL --exit-code 1` nas dependências.
   - **SAST:** `gosec -severity high` (Go) e `bandit -ll -ii` (Python).
4. **`docker-build-scan-push`:** `docker build --target prod` → **`trivy image
   --severity CRITICAL --exit-code 1` antes do push** → `amazon-ecr-login` →
   push `:<github.sha>` (`auth` também publica a imagem `-migrate-image`).
   Só em push (não em PR).
5. **`gitops-update`** (só push na `lab`): `kustomize edit set image` no overlay
   do serviço e commit `[skip ci]` na branch `lab`.

**Infra:** `infra-tf-plan` (PR) e `infra-tf-apply` (push) rodam
`terraform fmt/validate` + `tflint` + **`checkov` com `soft-fail: false`**
(`.checkov.yaml` com baseline justificada para o AWS Academy) +
**`trivy config --severity CRITICAL --exit-code 1`**.

A demonstração da regra de bloqueio (dependência com CVE crítico → pipeline
vermelho) está em [`DEVSECOPS-DEMO.md`](./DEVSECOPS-DEMO.md).

## Entrega Contínua (CD) & GitOps

Abandonamos o push direto de manifests via CI em favor de **GitOps**:

1. **Pasta de GitOps dedicada:** [`fase-3/gitops/`](./gitops/) — separada do
   código dos serviços. Os overlays Kustomize (`gitops/manifests/<svc>/`)
   reaproveitam os manifests da Fase 2 (`fase-2/<svc>-service/k8s/`) sem
   duplicar e **omitem o `secrets.yaml`** (base64), substituído por
   `ExternalSecret` + `ClusterSecretStore` do External Secrets Operator.
2. **ArgoCD:** instalado no EKS via Terraform (`modules/addons`, `helm_release`).
   Modelo **app-of-apps**: `gitops/root-app.yaml` (aponta para `gitops/apps/`
   com `directory.recurse`) gera 6 `Application` — os 5 microsserviços + a
   `platform` (ESO), esta com `sync-wave: -1`. `syncPolicy.automated` com
   `prune` e `selfHeal`.
3. **Atualização automática:** o job `gitops-update` do CI roda
   `kustomize edit set image` no `kustomization.yaml` do serviço e commita o
   bump (tag = `github.sha`) na branch `lab`.
4. **Sync:** o ArgoCD observa a branch `lab`, detecta o commit e sincroniza o
   cluster — sem `kubectl apply` local.

Cada microsserviço é uma `Application` independente, sincronizada do respectivo
`fase-3/gitops/manifests/<svc>`.

## Dificuldades Encontradas

> A confirmar com o grupo — sugestões de tópicos a documentar, com base no padrão das fases anteriores:
- Restrições de IAM do AWS Academy ao associar a `LabRole` via Terraform (ex.: permissões insuficientes para determinados recursos).
- Falsos positivos ou ruído inicial nos scans de SAST/SCA, exigindo ajuste de thresholds/allowlists.
- Ordenação de dependências no Terraform entre módulos (ex.: EKS depender da VPC, RDS depender das Subnets privadas).
- Sincronização inicial do ArgoCD (ex.: drift entre o estado do cluster criado manualmente na Fase 2 e o novo estado gerenciado via GitOps).

## Estimativa de Custos

![Estimativa de Custos AWS](/.github/estimativa-custos-fase3.png)

> Inserir aqui o print da estimativa de custos da AWS (Cost Explorer ou AWS Pricing Calculator), conforme exigido no relatório de entrega.

## Diagrama de Arquitetura

- Diagrama (SVG): [link do diagrama SVG]

![Diagrama de Arquitetura Fase 3](/.github/DiagramaArquiteturaFase3.png)

## Integrantes do Grupo

- [Aline Estevo da Silva](https://www.linkedin.com/in/aline-estevo)
- [Thiago de Melo Macedo](https://www.linkedin.com/in/thiago-melo-macedo)
- [Jefferson Fernandes de Freitas](#)
- [Vinicius Jorge de Oliveira](#)
- [Maurício Magnago Castro Sá](https://www.linkedin.com/in/mcastrosa)