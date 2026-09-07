output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Comando para obter acesso kubectl ao cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "ecr_repository_urls" {
  description = "URLs de todos os repositorios ECR (nome -> url), reunidos dos servicos."
  value       = merge([for s in module.service : s.ecr_repository_urls]...)
}

output "sqs_queue_url" {
  description = "URL da fila compartilhada, declarada pelo servico consumidor."
  value       = module.service[local.queue_consumer].queue_url
}

output "sqs_dlq_url" {
  description = "URL da DLQ da fila compartilhada."
  value       = module.service[local.queue_consumer].dlq_url
}

output "dynamodb_table" {
  description = "Nome da tabela DynamoDB do servico que a declara."
  value       = module.service[local.dynamodb_owner].dynamodb_table_name
}

output "redis_url" {
  description = "REDIS_URL para o evaluation-service."
  value       = module.elasticache.redis_url
}

output "rds_endpoints" {
  description = "Host de cada instancia RDS (servico -> host). So os servicos com db.enabled."
  value       = { for s in local.services : s.name => module.service[s.name].rds_endpoint if s.db.enabled }
}

output "rds_secret_arns" {
  description = "ARN do secret no Secrets Manager de cada RDS (servico -> arn)."
  value       = { for s in local.services : s.name => module.service[s.name].rds_secret_arn if s.db.enabled }
}

output "rds_database_urls" {
  description = "Connection string de cada RDS (servico -> url). Sensivel."
  value       = { for s in local.services : s.name => module.service[s.name].rds_database_url if s.db.enabled }
  sensitive   = true
}

output "keda_irsa_annotations" {
  description = "Anotacao de IRSA a aplicar no ServiceAccount do KEDA, por servico com queue.keda."
  value = {
    for s in local.services : s.name => module.service[s.name].keda_irsa_annotation
    if try(s.queue.keda, false)
  }
}

output "app_secret_names" {
  description = "Secrets de aplicacao (nao-RDS) no Secrets Manager, consumidos pelo ESO."
  value = {
    auth       = aws_secretsmanager_secret.auth_app.name
    evaluation = aws_secretsmanager_secret.evaluation_app.name
    analytics  = aws_secretsmanager_secret.analytics_app.name
  }
}
