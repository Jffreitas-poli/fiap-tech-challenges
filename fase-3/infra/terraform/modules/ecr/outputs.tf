output "repository_urls" {
  description = "Mapa nome -> URL do repositorio ECR."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "Mapa nome -> ARN do repositorio ECR."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}

output "registry_id" {
  description = "ID do registry (account id) que hospeda os repositorios."
  value       = values(aws_ecr_repository.this)[0].registry_id
}
