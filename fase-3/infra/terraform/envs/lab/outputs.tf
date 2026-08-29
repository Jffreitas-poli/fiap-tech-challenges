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
  description = "URLs dos repositorios ECR (nome -> url)."
  value       = module.ecr.repository_urls
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "sqs_dlq_url" {
  value = module.sqs.dlq_url
}

output "dynamodb_table" {
  value = module.dynamodb.table_name
}

output "redis_url" {
  description = "REDIS_URL para o evaluation-service."
  value       = module.elasticache.redis_url
}

output "rds_endpoints" {
  description = "Host de cada instancia RDS (servico -> host)."
  value       = { for k, m in module.rds : k => m.endpoint }
}

output "rds_secret_arns" {
  description = "ARN do secret no Secrets Manager de cada RDS (servico -> arn)."
  value       = { for k, m in module.rds : k => m.secret_arn }
}

output "rds_database_urls" {
  description = "Connection string de cada RDS (servico -> url). Sensivel."
  value       = { for k, m in module.rds : k => m.database_url }
  sensitive   = true
}
