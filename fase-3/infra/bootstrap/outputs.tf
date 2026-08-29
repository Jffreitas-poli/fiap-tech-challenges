output "state_bucket_name" {
  description = "Nome do bucket S3 para configurar em envs/*/backend.tf."
  value       = aws_s3_bucket.tfstate.id
}

output "lock_table_name" {
  description = "Nome da tabela DynamoDB de lock para configurar em envs/*/backend.tf."
  value       = aws_dynamodb_table.tflock.name
}

output "region" {
  description = "Regiao do backend."
  value       = var.region
}
