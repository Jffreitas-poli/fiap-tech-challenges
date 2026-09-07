output "state_bucket_name" {
  description = "Configurar em envs/prod/backend.tf."
  value       = aws_s3_bucket.tfstate.id
}

output "lock_table_name" {
  description = "Configurar em envs/prod/backend.tf."
  value       = aws_dynamodb_table.tflock.name
}

output "github_actions_role_arn" {
  description = "Setar como GitHub repo variable PROD_AWS_ROLE_ARN (role-to-assume via OIDC)."
  value       = module.github_actions.role_arn
}

output "oidc_provider_arn" {
  value = module.github_actions.oidc_provider_arn
}

output "eks_cluster_role_arn" {
  description = "Passar em envs/prod/main.tf -> module.eks.cluster_role_arn."
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "Passar em envs/prod/main.tf -> module.eks.node_role_arn."
  value       = aws_iam_role.eks_node.arn
}
