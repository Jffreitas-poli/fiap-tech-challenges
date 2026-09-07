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
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "dynamodb_table" {
  value = module.dynamodb.table_name
}

output "redis_url" {
  value = module.elasticache.redis_url
}

output "rds_endpoints" {
  value = { for k, m in module.rds : k => m.endpoint }
}

output "rds_database_urls" {
  value     = { for k, m in module.rds : k => m.database_url }
  sensitive = true
}

output "app_secret_names" {
  value = {
    auth       = aws_secretsmanager_secret.auth_app.name
    evaluation = aws_secretsmanager_secret.evaluation_app.name
    analytics  = aws_secretsmanager_secret.analytics_app.name
  }
}
