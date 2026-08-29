output "role_arn" {
  description = "ARN da role para usar em role-to-assume nos workflows."
  value       = aws_iam_role.gha.arn
}

output "role_name" {
  description = "Nome da role."
  value       = aws_iam_role.gha.name
}

output "oidc_provider_arn" {
  description = "ARN do OIDC provider do GitHub."
  value       = local.provider_arn
}
