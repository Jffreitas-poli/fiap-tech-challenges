# Passo a passo — Provisionar a infra da Fase 3 do zero

Guia sequencial para levar o ToggleMaster da Fase 2 (operação manual) para a
Fase 3 (Terraform + CI/CD + GitOps). Execute os passos **na ordem**.

- **Conta / região:** AWS Academy `361075236043`, `us-east-1`
- **Cluster:** `tc-eks` · **Namespace:** `toggle`
- **State remoto:** `s3://tc-fiap-tfstate-361075236043`, lock `tc-fiap-tflock`

> Sob o AWS Academy o Terraform **não cria IAM Role/Policy/OIDC**. Cluster e nodes
> usam a `LabRole`; os workflows usam chaves estáticas da sessão do lab.

---

## Passo 0 — Pré-requisitos (uma vez, na máquina de quem for operar)

| Ferramenta | Versão mínima | Verificar |
|---|---|---|
| Terraform | 1.9 | `terraform version` |
| AWS CLI | 2.x | `aws --version` |
| kubectl | 1.29 | `kubectl version --client` |
| jq | 1.6 | `jq --version` |
| git | — | `git --version` |

Clone o repositório e entre na branch de trabalho:

```bash
git clone https://github.com/NyEstevo/fiap-tech-challenges.git
cd fiap-tech-challenges
git checkout chore/add-fase-3    # ou a branch/PR onde a infra foi mergeada
```

---

## Passo 1 — Obter as credenciais do AWS Academy

1. Abra o laboratório no Vocareum → **AWS Details** → **AWS CLI: Show**.
2. Copie o bloco `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`.
3. Exporte no shell atual (valem ~4h; ao expirar, repita este passo):

```bash
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_DEFAULT_REGION="us-east-1"
```

4. Valide:

```bash
aws sts get-caller-identity
# Account deve ser 361075236043
```

---

## Passo 2 — Bootstrap do state remoto (uma vez por conta)

Cria o bucket S3 e a tabela de lock que **todas** as composições usam.
Roda com state **local** (é o que cria o backend).

```bash
cd fase-3/infra/bootstrap
terraform init
terraform apply
# digite: yes
```

Confirme:

```bash
aws s3api head-bucket --bucket tc-fiap-tfstate-361075236043 && echo "bucket OK"
aws dynamodb describe-table --table-name tc-fiap-tflock --query 'Table.TableStatus'
```

> Se o bucket já existir de uma tentativa anterior, rode
> `terraform import aws_s3_bucket.tfstate tc-fiap-tfstate-361075236043` e
> `terraform import aws_dynamodb_table.tflock tc-fiap-tflock` antes do apply.

Volte para a raiz:

```bash
cd ../../..
```

---

## Passo 3 — Configurar o GitHub (Secrets, Variables, Environments)

Feito uma vez no repositório (precisa de permissão de admin).

### 3.1 Secrets do repositório

`Settings → Secrets and variables → Actions → New repository secret`

| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID` | do Passo 1 |
| `AWS_SECRET_ACCESS_KEY` | do Passo 1 |
| `AWS_SESSION_TOKEN` | do Passo 1 |

> **Toda sessão nova do lab** exige reatualizar esses 3 secrets, senão os
> workflows falham com `ExpiredToken`.

### 3.2 Variables do repositório (opcional)

`... → Variables → New repository variable`

| Variable | Valor |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `TF_VERSION` | `1.9.8` |

### 3.3 Environments

`Settings → Environments → New environment`

- Criar **`lab`** e **`prod`**.
- Em cada um: **Required reviewers** = 1 (você/colega) e **Deployment branches** = `main` apenas.
- Isso segura `infra-tf-apply` e `infra-tf-destroy` atrás de aprovação manual.

---

## Passo 4 — Preparar o `terraform.tfvars` do ambiente `lab`

```bash
cd fase-3/infra/terraform/envs/lab
cp terraform.tfvars.example terraform.tfvars   # já vem versionado; edite se necessário
```

Ajuste em `terraform.tfvars` se preciso:

- `admin_principal_arns` — inclua o ARN da role/usuário que vai rodar `kubectl`
  (ex.: `arn:aws:iam::361075236043:role/LabRole` já está lá).
- CIDRs, tipos de instância — os defaults já são enxutos para o Academy.

**Não** coloque senha de banco aqui — o Terraform gera e guarda no Secrets Manager.

---

## Passo 5 — Primeiro apply (encenado)

Os providers `kubernetes`/`helm` só inicializam depois que o cluster existe.
Por isso o primeiro apply é em três etapas.

```bash
# ainda em fase-3/infra/terraform/envs/lab
terraform init                       # agora com backend S3

terraform apply \
  -target=module.networking \
  -target=module.eks
# yes  -> cria VPC, subnets, NAT, cluster EKS e node group (~15 min)

terraform apply
# yes  -> ECR, RDS x3, ElastiCache, SQS, DynamoDB, add-ons Helm
#         (metrics-server, ingress-nginx, KEDA, ArgoCD)
#         (~15-20 min, RDS é o mais lento)

terraform apply -var bootstrap_gitops_root_app=true
# yes  -> cria a root Application do ArgoCD (kubernetes_manifest).
#         Separado porque esse recurso exige conexão viva com a API do
#         cluster já no plan -- só funciona com o EKS + ArgoCD no ar.
#         Alternativa manual: kubectl apply -f fase-3/gitops/root-app.yaml
```

Applies seguintes: `terraform apply -var bootstrap_gitops_root_app=true`.

---

## Passo 6 — Pós-apply: acesso ao cluster e Secrets do K8s

### 6.1 kubeconfig

```bash
aws eks update-kubeconfig --name tc-eks --region us-east-1
kubectl get nodes          # 2 nodes Ready
```

### 6.2 Secrets do K8s — via External Secrets Operator

Não é mais passo manual. O `terraform apply` publica no **AWS Secrets Manager**:

| Secret ASM | Conteúdo | Origem |
|---|---|---|
| `tc-rds-{auth,flag,targeting}-credentials` | `{username,password,host,url,...}` | módulo `rds` |
| `tc-auth-app` | `{MASTER_KEY}` | `random_password` |
| `tc-evaluation-app` | `{SERVICE_API_KEY, REDIS_URL, AWS_SQS_URL, AWS_REGION}` | `random_password` + módulos `elasticache`/`sqs` |
| `tc-analytics-app` | `{AWS_SQS_URL, AWS_DYNAMODB_TABLE, AWS_REGION}` | módulos `sqs`/`dynamodb` |

O **External Secrets Operator** (instalado pelo módulo `addons`) + o
`ClusterSecretStore` `aws-secrets-manager` (ArgoCD app `platform`) leem esses
valores e materializam o Secret `<svc>-secret` no namespace `toggle` — o mesmo
nome que cada `deployment.yaml` referencia em `envFrom`. Sem `kubectl create secret`.

O ESO autentica na AWS com **chaves estáticas da sessão** (não há IRSA no
Academy e o pod não alcança o IMDS do node). O mesmo vale para os pods
`analytics` e `evaluation`, que falam direto com SQS/DynamoDB pela cadeia
padrão do SDK. O `terraform apply` (`null_resource.eso_aws_creds`) cria, a
partir das env vars `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` /
`AWS_SESSION_TOKEN` do Passo 4, dois Secrets:

- `aws-static-creds` (ns `external-secrets`, chaves kebab-case) — usado pelo
  `ClusterSecretStore` em `auth.secretRef`;
- `aws-session-creds` (ns `toggle`, chaves `AWS_*`) — adicionado ao `envFrom`
  dos deployments `analytics` / `evaluation` via patch no kustomization.

**O session token expira ~4h** — quando os `ExternalSecret` pararem de
sincronizar ou o worker SQS do `analytics` logar `Unable to locate
credentials`, re-rode o `infra-tf-apply` (recria os dois Secrets) ou:

```bash
kubectl -n external-secrets create secret generic aws-static-creds \
  --from-literal=access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY" \
  --from-literal=session-token="$AWS_SESSION_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n toggle create secret generic aws-session-creds \
  --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  --from-literal=AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

# aplicar as novas creds: reinicia os pods que leem o Secret
kubectl -n toggle rollout restart deploy/analytics-deployment deploy/evaluation-deployment
```

Conferir:

```bash
kubectl get clustersecretstore aws-secrets-manager     # STATUS Valid
kubectl -n toggle get externalsecrets                  # SecretSynced=True
kubectl -n toggle get secret auth-secret flag-secret targeting-secret evaluation-secret analytics-secret
```

- Os `configmap.yaml` só guardam valor **estático** (`PORT`, URLs de serviço
  in-cluster). `REDIS_URL` / `AWS_SQS_URL` / `AWS_DYNAMODB_TABLE` / `AWS_REGION`
  vêm do ASM (eram valores da fase-2, `us-east-2`, no configmap).
- `analytics-deployment` ganha `secretRef: analytics-secret` e
  `secretRef: aws-session-creds` no `envFrom` via patch no kustomization (na
  fase-2 só tinha `configMapRef`); `evaluation-deployment` ganha
  `secretRef: aws-session-creds`. Sem esse Secret o boto3/SDK não acha
  credencial e o worker SQS falha com `Unable to locate credentials`.
- `MASTER_KEY` / `SERVICE_API_KEY` são gerados; para chamadas admin, leia com
  `aws secretsmanager get-secret-value --secret-id tc-auth-app`.
- A `SERVICE_API_KEY` é registrada na tabela `api_keys` do auth pelo Job
  `auth-seed-service-key` (hook `PostSync` do ArgoCD, `manifests/auth/seed-job.yaml`)
  — insere `sha256hex(SERVICE_API_KEY)`, idempotente. Sem passo manual.

---

## Passo 7 — Validar a infraestrutura

### 7.1 Recursos AWS

```bash
aws eks describe-cluster --name tc-eks --region us-east-1 --query 'cluster.status'          # ACTIVE
aws ecr describe-repositories --region us-east-1 --query 'repositories[].repositoryName'     # 5 repos tech-challenge/*
aws rds describe-db-instances --region us-east-1 \
  --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus]' --output table              # tc-rds-auth/flag/targeting = available
aws elasticache describe-replication-groups --region us-east-1 \
  --query 'ReplicationGroups[].[ReplicationGroupId,Status]' --output table                    # tc-redis = available
aws sqs get-queue-url --queue-name tc-sqs --region us-east-1
aws sqs get-queue-url --queue-name tc-sqs-dlq --region us-east-1
aws dynamodb describe-table --table-name tc-dynamo --region us-east-1 --query 'Table.TableStatus'  # ACTIVE
aws secretsmanager list-secrets --region us-east-1 --query 'SecretList[].Name'                 # tc-rds-*-credentials
```

### 7.2 Cluster e add-ons

```bash
kubectl get pods -n kube-system | grep metrics-server     # Running
kubectl get pods -n ingress-nginx                          # controller Running (2 réplicas)
kubectl get pods -n keda                                   # operator/metrics-apiserver Running
kubectl get pods -n argocd                                 # server/repo-server/... Running
kubectl get scaledobject -n toggle                         # analytics — READY True
```

---

## Passo 8 — Verificar o GitOps (ArgoCD)

```bash
kubectl get applications -n argocd
# toggle-master-root + auth/flag/targeting/evaluation/analytics-service
# Objetivo: SYNC STATUS = Synced, HEALTH = Healthy
```

Acessar a UI (rápido, sem ingress):

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80 &
# usuário: admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
# abra http://localhost:8080
```

Testar o roteamento externo:

```bash
NLB=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s "http://$NLB/auth/health"
curl -s "http://$NLB/flag/health"
```

Se um Application ficar `Degraded` por falta de Secret, volte ao **Passo 6.2**.

---

## Passo 9 — Fluxo de trabalho contínuo

A partir daqui, **não se aplica mais Terraform da máquina local**.

### Mudança de infra

1. Crie uma branch e altere algo em `fase-3/infra/terraform/**`.
2. Abra o PR → o workflow **`infra-tf-plan`** roda `fmt/validate/tflint/checkov/plan`
   e comenta o `plan` no PR.
3. Revise o plan no comentário. Se ok, faça merge na `main`.
4. O workflow **`infra-tf-apply`** dispara, pede aprovação no Environment `lab`
   e aplica. Os outputs aparecem no **Step Summary** da run.

> Antes de cada run, confirme que os 3 secrets `AWS_*` estão atualizados (Passo 3.1).

### Deploy de aplicação (quando os workflows de app existirem)

1. CI do serviço: build → testes → SAST/SCA → build da imagem → push no ECR
   com tag `vX.Y.Z-<sha>`.
2. Passo final do CI: `yq -i '.images[0].newTag = "<tag>"'` no
   `fase-3/gitops/manifests/<svc>/kustomization.yaml` + commit/push.
3. O ArgoCD detecta o commit e sincroniza o cluster — sem `kubectl apply`.

---

## Passo 10 — Destruir o ambiente (fim do lab / economia)

**Preferencial — pelo GitHub:**
`Actions → infra-tf-destroy → Run workflow` → `environment: lab`,
`confirm: DESTROY` → aprove no Environment.

**Local (alternativa):**

```bash
cd fase-3/infra/terraform/envs/lab
terraform destroy
```

Ordem interna: root-app → add-ons → dbs/mensageria → EKS → networking.
O `bootstrap/` (bucket + lock) tem `prevent_destroy` e **não** é removido —
para removê-lo de fato: `cd fase-3/infra/bootstrap && terraform destroy`
(exige tirar o `prevent_destroy` antes).

> Se o `destroy` travar no ingress-nginx (NLB pendente), rode
> `kubectl delete svc -n ingress-nginx ingress-nginx-controller` e repita.

---

## Passo 11 — Problemas comuns

| Sintoma | Causa | Ação |
|---|---|---|
| `ExpiredToken` / `InvalidClientTokenId` | credenciais do lab expiraram | refazer Passo 1 e Passo 3.1 |
| `Error: Get "http://localhost/api/..."` no 1º apply | providers k8s/helm sem cluster | usar o apply encenado do Passo 5 |
| `UnauthorizedOperation` em `iam:*` | tentativa de criar IAM | confirmar que nenhum módulo novo cria Role/Policy; usar `LabRole` |
| Pods `CreateContainerConfigError` | Secret do banco não existe | Passo 6.2 |
| ArgoCD app `ComparisonError` de kustomize | load restrictor | já tratado via `kustomize.buildOptions` no módulo `addons`; rode `terraform apply` de novo |
| `terraform plan` quer recriar o cluster | mudança em campo imutável (subnets/versão) | revisar o diff antes de aplicar |
| Lock do state preso | run anterior abortada | `terraform force-unlock <LOCK_ID>` |

---

## Checklist de entrega da Fase 3

- [ ] Passo 2: bucket S3 + tabela de lock criados
- [ ] Passo 3: 3 secrets `AWS_*` + Environments `lab`/`prod` com required reviewer
- [ ] Passo 5: `terraform apply` do `envs/lab` concluído sem erro
- [ ] Passo 7: EKS `ACTIVE`, 3 RDS `available`, Redis `available`, SQS + DLQ, DynamoDB `ACTIVE`, 5 repos ECR
- [ ] Passo 7.2: metrics-server, ingress-nginx, KEDA e ArgoCD `Running`
- [ ] Passo 8: 6 Applications do ArgoCD `Synced/Healthy`; `/auth/health` responde pelo NLB
- [ ] Passo 9: PR de teste gera comentário de `plan`; merge na `main` aplica com aprovação
- [ ] Print da estimativa de custos (AWS Pricing Calculator / Cost Explorer) para o relatório
