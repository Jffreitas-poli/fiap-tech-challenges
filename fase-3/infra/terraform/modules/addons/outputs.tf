output "ingress_nginx_namespace" {
  description = "Namespace do ingress-nginx (vazio se desabilitado)."
  value       = var.enable_ingress_nginx ? "ingress-nginx" : ""
}

output "keda_namespace" {
  description = "Namespace do KEDA (vazio se desabilitado)."
  value       = var.enable_keda ? "keda" : ""
}

output "argocd_namespace" {
  description = "Namespace do ArgoCD (vazio se desabilitado)."
  value       = var.enable_argocd ? "argocd" : ""
}
