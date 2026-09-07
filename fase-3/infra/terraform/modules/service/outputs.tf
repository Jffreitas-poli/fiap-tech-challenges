output "name" {
  description = "Nome logico do servico (chave do for_each no root)."
  value       = var.spec.name
}

output "ecr_repository_urls" {
  description = "Mapa nome do repositorio -> URL do ECR deste servico."
  value       = module.ecr.repository_urls
}

output "ecr_repository_names" {
  description = "Nomes dos repositorios ECR deste servico (1, ou 2 quando db.migrate = dedicated)."
  value       = local.ecr_repositories
}

output "rds_endpoint" {
  description = "Host DNS do RDS. null quando db.enabled = false."
  value       = one(module.rds[*].endpoint)
}

output "rds_secret_arn" {
  description = "ARN do secret com as credenciais do RDS. null quando db.enabled = false."
  value       = one(module.rds[*].secret_arn)
}

output "rds_database_url" {
  description = "Connection string completa do RDS. null quando db.enabled = false."
  value       = one(module.rds[*].database_url)
  sensitive   = true
}

output "queue_url" {
  description = "URL da fila SQS. Preenchido so no servico consumidor, que e quem declara a fila."
  value       = one(module.sqs[*].queue_url)
}

output "queue_arn" {
  description = "ARN da fila SQS usada por este servico (produtor ou consumidor). Montado a partir de region/account_id."
  value       = local.queue_arn
}

output "dlq_url" {
  description = "URL da DLQ. Preenchido so no servico consumidor."
  value       = one(module.sqs[*].dlq_url)
}

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB. null quando dynamodb.enabled = false."
  value       = one(module.dynamodb[*].table_name)
}

output "keda_irsa_role_arn" {
  description = "ARN da role de IRSA do KEDA. null no lab (Academy nao cria role; o KEDA usa aws-session-creds)."
  value       = one(aws_iam_role.keda[*].arn)
}

output "keda_irsa_annotation" {
  description = "Anotacao a aplicar no ServiceAccount do KEDA para ativar o IRSA. Vazio quando create_iam_role = false. O ServiceAccount em si pertence ao chart do KEDA/ArgoCD, nao ao Terraform."
  value = local.create_keda_iam ? {
    "eks.amazonaws.com/role-arn" = one(aws_iam_role.keda[*].arn)
  } : {}
}
