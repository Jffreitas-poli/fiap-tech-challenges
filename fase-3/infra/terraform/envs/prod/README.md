# envs/prod — código pronto, NÃO aplicado

Sob o orçamento do AWS Academy só o ambiente `lab` é provisionado. Este
diretório já traz a **composição completa** do prod (mesmos módulos do `lab`,
com HA e IAM próprio) — falta apenas rodar numa conta AWS real.

Diferenças em relação ao `lab`:

| | lab | prod |
|---|---|---|
| IAM | `LabRole` (Academy) via `data source` | roles próprias, criadas em `bootstrap/prod` |
| Auth do CI | chaves estáticas de sessão (GitHub Secrets) | **OIDC** (`role-to-assume`) |
| NAT Gateway | 1 compartilhado | 1 por AZ |
| RDS | single-AZ, sem deletion protection | Multi-AZ, deletion protection, backup 7d |
| Redis | 1 node | 2 nodes (failover) |
| DynamoDB | sem PITR | PITR ligado |
| AZs | 2 | 3 |
| Nodes | t3.medium 1–4 | t3.large 2–6 |

## Passos para ativar o prod

1. **Bootstrap** (uma vez, local, com credenciais de admin da conta pessoal):
   ```bash
   cd fase-3/infra/bootstrap/prod
   terraform init && terraform apply
   ```
   Cria: bucket S3 + lock DynamoDB do state de prod, OIDC provider do GitHub,
   role `tc-github-actions-prod` (policy *least privilege* dedicada — nunca
   `AdministratorAccess`), e as roles `tc-eks-cluster-prod` / `tc-eks-node-prod`.
   Os diretórios `bootstrap/**` usam state local e **não passam pelo CI**.

2. **GitHub → Settings → Secrets and variables → Actions → Variables**:
   - `AWS_REGION` = `us-east-1`
   - `PROD_AWS_ROLE_ARN` = output `github_actions_role_arn` do passo 1

3. **GitHub → Settings → Environments**: criar `prod` com **Required reviewers**
   (≥ 1) e **Deployment branches: `main` only**. (O environment `production`
   citado no prompt = este `prod`.)

4. **`terraform.tfvars`**: copiar de `terraform.tfvars.example` e preencher
   `account_id`, `eks_cluster_role_arn`, `eks_node_role_arn` (outputs do passo 1).

5. **`root-app.yaml`**: em prod o ArgoCD deve seguir a branch `main`
   (o arquivo atual aponta para `lab`). Ajustar `targetRevision` ou usar um
   `root-app-prod.yaml` dedicado antes do primeiro apply.

6. **Apply encenado** (igual ao lab):
   ```bash
   cd fase-3/infra/terraform/envs/prod
   terraform init
   terraform apply -target=module.networking -target=module.eks
   terraform apply
   ```

Os workflows `infra-tf-apply` / `_reusable-ci-service` já resolvem
`environment = prod` quando o push é na branch `main`, e a composite action
`.github/actions/aws-auth` já troca para OIDC nesse caso — nada a mudar nos
workflows para ativar o prod.
