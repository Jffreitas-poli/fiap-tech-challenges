# fase-3/infra — Infraestrutura como Código (Terraform)

Provisiona a plataforma dos 5 microsserviços do ToggleMaster na AWS:
VPC + EKS (`tc-eks`) + 3× RDS PostgreSQL + ElastiCache Redis + SQS + DynamoDB
+ 5 repositórios ECR + add-ons de cluster (metrics-server, ingress-nginx,
KEDA, ArgoCD).

```
bootstrap/                 # roda 1×, state LOCAL, cria o bucket S3 + tabela de lock
terraform/
  modules/                 # networking, eks, ecr, rds, elasticache, sqs, dynamodb,
                           # addons, iam_oidc_github (este último NÃO é usado no Academy)
  envs/
    lab/                   # único ambiente aplicado  (state key: fase-3/lab/terraform.tfstate)
    prod/                  # scaffolding — ver envs/prod/README.md
```

## Restrições do AWS Academy / Vocareum

- O Terraform **não cria nenhuma IAM Role, Policy ou OIDC provider**.
- O cluster EKS e o node group usam a **`LabRole`** existente (`data "aws_iam_role" "lab"`).
- O `analytics-service` e o operador KEDA acessam a fila SQS pelas credenciais
  da **role de instância dos nodes (LabRole)** via IMDS — não há IRSA real.
- Os workflows do GitHub Actions autenticam com as **chaves estáticas da sessão
  do lab** (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN`),
  guardadas como GitHub Secrets e renovadas a cada sessão (~4h).

## 1. Bootstrap (uma vez)

```bash
cd fase-3/infra/bootstrap
terraform init
terraform apply            # cria s3://tc-fiap-tfstate-047719652987 e a tabela tc-fiap-tflock
```

Alternativa em AWS CLI: ver a seção "Bootstrap" no plano
(`.claude/plans/…` / documentação da Fase 3).

## 2. Primeiro apply do ambiente `lab` (encenado)

Os providers `kubernetes`/`helm` só conseguem inicializar depois que o cluster
existe, então o primeiro apply é feito em dois passos:

```bash
cd fase-3/infra/terraform/envs/lab
cp terraform.tfvars.example terraform.tfvars   # já vem versionado; ajuste se necessário
terraform init
terraform apply -target=module.networking -target=module.eks   # VPC + cluster + nodes
terraform apply                                                 # ecr, dbs, addons, argocd, root-app
```

Applies seguintes: só `terraform apply`.

### Ordem de dependências (resolvida pelo grafo do Terraform)

1. `networking` → 2. `eks` → 3. `ecr` (paralelo) → 4. `rds` / `elasticache` /
`sqs` / `dynamodb` (SGs liberam 5432/6379 só para o SG dos nodes) →
5. `addons` (Helm) → 6. `kubernetes_manifest.root_app` (ArgoCD passa a
sincronizar `fase-3/gitops/`).

## 3. Pós-apply

```bash
aws eks update-kubeconfig --name tc-eks --region us-east-2

# Criar os Secrets do K8s a partir dos outputs (enquanto não há External Secrets):
cd fase-3/infra/terraform/envs/lab
for svc in auth flag targeting; do
  URL=$(terraform output -json rds_database_urls | jq -r ".$svc")
  kubectl -n toggle create secret generic ${svc}-secret \
    --from-literal=DATABASE_URL="$URL" --dry-run=client -o yaml | kubectl apply -f -
done
```

O `evaluation-service` consome `REDIS_URL` (output `redis_url`) e o
`SERVICE_API_KEY` (secret próprio já versionado). O `analytics-service` não
tem secret — usa configmap + role dos nodes.

## 4. Verificação

```bash
# AWS
aws eks describe-cluster --name tc-eks --region us-east-2 --query 'cluster.status'
aws ecr describe-repositories --region us-east-2 --query 'repositories[].repositoryName'
aws rds describe-db-instances --region us-east-2 --query 'DBInstances[].DBInstanceIdentifier'
aws elasticache describe-replication-groups --region us-east-2 --query 'ReplicationGroups[].ReplicationGroupId'
aws sqs get-queue-url --queue-name tc-sqs --region us-east-2
aws dynamodb describe-table --table-name tc-dynamo --region us-east-2 --query 'Table.TableStatus'

# Cluster
kubectl get nodes
kubectl get pods -n ingress-nginx
kubectl get pods -n keda
kubectl get pods -n argocd
kubectl get applications -n argocd          # toggle-master-root + 5 serviços = Synced/Healthy
kubectl get scaledobject -n toggle          # analytics — KEDA ativo
NLB=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s "http://$NLB/auth/health"; curl -s "http://$NLB/flag/health"
```

## 5. Destroy

Via workflow `infra-tf-destroy` (input `confirm=DESTROY`, Environment com
required reviewer) ou local:

```bash
cd fase-3/infra/terraform/envs/lab
terraform destroy
```

O bucket de state e a tabela de lock (`bootstrap/`) têm `prevent_destroy` e
não são removidos por este destroy.
