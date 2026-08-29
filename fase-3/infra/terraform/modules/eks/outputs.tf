output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint HTTPS do API server."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca" {
  description = "Certificate authority do cluster (base64)."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  description = "URL do OIDC issuer do cluster (informativo; IRSA nao e usado no Academy)."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_security_group_id" {
  description = "Security Group gerenciado pelo EKS para o control plane."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security Group efetivo dos nodes (o cluster SG, compartilhado com os nodes gerenciados)."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_name" {
  description = "Nome do managed node group."
  value       = aws_eks_node_group.default.node_group_name
}
