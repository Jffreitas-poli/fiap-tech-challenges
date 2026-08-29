output "endpoint" {
  description = "Host DNS da instancia RDS."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Porta do banco."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Nome do banco."
  value       = aws_db_instance.this.db_name
}

output "secret_arn" {
  description = "ARN do secret no Secrets Manager com as credenciais."
  value       = aws_secretsmanager_secret.this.arn
}

output "database_url" {
  description = "Connection string completa (sensivel)."
  value       = "postgres://${var.username}:${random_password.this.result}@${aws_db_instance.this.address}:5432/${var.db_name}"
  sensitive   = true
}
