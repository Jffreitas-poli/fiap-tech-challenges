# envs/prod — scaffolding (NAO aplicado)

Sob o orcamento do AWS Academy so o ambiente `lab` e provisionado. Esta
pasta existe para deixar o caminho pronto: backend com chave S3 propria
(`fase-3/prod/terraform.tfstate`) e `terraform.tfvars` proprio.

## Para ativar o prod

1. Copie os `.tf` de `../lab/` para ca (ou crie um symlink):
   ```bash
   cp ../lab/{versions.tf,providers.tf,variables.tf,main.tf,outputs.tf} .
   ```
2. Ajuste o naming para o sufixo `-prod` em `main.tf` (`locals.env = "prod"`,
   `cluster_name`, `tc-rds-*-prod`, `tc-sqs-prod`, `tc-redis-prod`,
   `tc-dynamo-prod`, repos ECR se aplicavel) e em `terraform.tfvars`.
3. Use CIDRs de VPC que nao colidam com o lab (ex.: `10.30.0.0/16`).
4. `terraform init` (vai usar a chave `fase-3/prod/...`) e siga a mesma
   ordem de apply encenado do lab.

Os workflows ja aceitam `environment: prod` via `workflow_dispatch`.
