output "table_name" {
  description = "Nome da tabela (AWS_DYNAMODB_TABLE do analytics-service)."
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN da tabela."
  value       = aws_dynamodb_table.this.arn
}

output "stream_arn" {
  description = "ARN do stream (vazio se streams desabilitados)."
  value       = aws_dynamodb_table.this.stream_arn
}
