output "primary_endpoint" {
  description = "Endpoint primario (host) do Redis."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint" {
  description = "Endpoint de leitura (host)."
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "port" {
  description = "Porta do Redis."
  value       = 6379
}

output "redis_url" {
  description = "URL pronta para o REDIS_URL do evaluation-service."
  value       = "${var.transit_encryption_enabled ? "rediss" : "redis"}://${aws_elasticache_replication_group.this.primary_endpoint_address}:6379/0"
}
