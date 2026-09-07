variable "cluster_name" {
  description = "Nome do cluster EKS."
  type        = string
}

variable "cluster_version" {
  description = "Versao do Kubernetes do control plane. Use uma versao ainda suportada pelo EKS (1.30 saiu de suporte padrao)."
  type        = string
  default     = "1.31"

  validation {
    condition     = can(regex("^\\d+\\.\\d+$", var.cluster_version))
    error_message = "cluster_version deve estar no formato MAJOR.MINOR (ex.: 1.31)."
  }
}

variable "node_ami_type" {
  description = "AMI type do managed node group. AL2 foi descontinuado; use AL2023."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "subnet_ids" {
  description = "Subnets privadas para o control plane (ENIs) e para o node group."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Subnets publicas adicionais associadas ao cluster (para o NLB do ingress)."
  type        = list(string)
  default     = []
}

variable "lab_role_arn" {
  description = "ARN da LabRole do AWS Academy, usada tanto pelo cluster quanto pelos nodes (nenhuma IAM Role e criada pelo Terraform)."
  type        = string
}

variable "cluster_role_arn" {
  description = "prod: ARN da role do control plane (bootstrap/prod). Vazio => usa lab_role_arn."
  type        = string
  default     = ""
}

variable "node_role_arn" {
  description = "prod: ARN da role dos nodes (bootstrap/prod). Vazio => usa lab_role_arn."
  type        = string
  default     = ""
}

variable "node_instance_types" {
  description = "Tipos de instancia do managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min" {
  description = "Minimo de nodes."
  type        = number
  default     = 1

  validation {
    condition     = var.node_min >= 1
    error_message = "node_min deve ser >= 1."
  }
}

variable "node_desired" {
  description = "Quantidade desejada de nodes."
  type        = number
  default     = 2

  validation {
    condition     = var.node_desired >= var.node_min && var.node_desired <= var.node_max
    error_message = "node_desired deve estar entre node_min e node_max."
  }
}

variable "node_max" {
  description = "Maximo de nodes."
  type        = number
  default     = 4

  validation {
    condition     = var.node_max >= var.node_min
    error_message = "node_max deve ser >= node_min."
  }
}

variable "node_disk_size" {
  description = "Tamanho do disco (GiB) de cada node."
  type        = number
  default     = 20
}

variable "endpoint_public_access" {
  description = "Se o endpoint do API server e acessivel publicamente (necessario para o CI/equipe sem VPN)."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs autorizados a acessar o endpoint publico do API server."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_principal_arns" {
  description = "ARNs de IAM (roles/users) que recebem acesso de cluster-admin via EKS access entries."
  type        = list(string)
  default     = []
}

variable "cluster_addons" {
  description = "Addons gerenciados do EKS a habilitar."
  type        = list(string)
  default     = ["coredns", "kube-proxy", "vpc-cni"]
}

variable "tags" {
  description = "Tags adicionais."
  type        = map(string)
  default     = {}
}
