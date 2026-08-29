variable "cluster_name" {
  description = "Nome do cluster EKS (usado apenas para dependencia/legibilidade)."
  type        = string
}

variable "enable_metrics_server" {
  type    = bool
  default = true
}

variable "enable_ingress_nginx" {
  type    = bool
  default = true
}

variable "enable_keda" {
  type    = bool
  default = true
}

variable "enable_argocd" {
  type    = bool
  default = true
}

variable "ingress_nginx_values_path" {
  description = "Caminho para o arquivo de values do chart ingress-nginx (reusa fase-2/ingress-nginx-values.yaml)."
  type        = string
}

variable "metrics_server_chart_version" {
  type    = string
  default = "3.12.1"
}

variable "ingress_nginx_chart_version" {
  type    = string
  default = "4.11.3"
}

variable "keda_chart_version" {
  type    = string
  default = "2.15.1"
}

variable "argocd_chart_version" {
  type    = string
  default = "7.6.12"
}

variable "argocd_extra_values" {
  description = "Values adicionais (YAML) mesclados na instalacao do ArgoCD."
  type        = string
  default     = ""
}
