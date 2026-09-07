variable "region" {
  description = "Regiao AWS."
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "ID da conta AWS de prod (conta pessoal)."
  type        = string
}

variable "environment" {
  description = "Nome do ambiente. Entra nas tags (Environment) e no sufixo dos nomes de recurso ('-prod')."
  type        = string
  default     = "prod"
}

variable "eks_cluster_role_arn" {
  description = "ARN da role do control plane do EKS (output de bootstrap/prod)."
  type        = string
}

variable "eks_node_role_arn" {
  description = "ARN da role dos nodes do EKS (output de bootstrap/prod)."
  type        = string
}

variable "bootstrap_gitops_root_app" {
  description = "Aplica a root Application (app-of-apps) do ArgoCD via kubectl no apply."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Nome do cluster EKS."
  type        = string
  default     = "tc-eks-prod"
}

variable "cluster_version" {
  description = "Versao do Kubernetes."
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR da VPC (nao pode colidir com o lab 10.20/16)."
  type        = string
  default     = "10.30.0.0/16"
}

variable "azs" {
  description = "Availability Zones."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets publicas."
  type        = list(string)
  default     = ["10.30.0.0/20", "10.30.16.0/20", "10.30.32.0/20"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas."
  type        = list(string)
  default     = ["10.30.128.0/20", "10.30.144.0/20", "10.30.160.0/20"]
}

variable "admin_principal_arns" {
  description = "ARNs de IAM que recebem cluster-admin via EKS access entries."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  description = "Tipos de instancia dos nodes (prod usa instancias maiores)."
  type        = list(string)
  default     = ["t3.large"]
}

########################################################################
# IAM
#
# Em prod a conta e propria: o Terraform cria o OIDC provider do cluster e as
# roles de IRSA do KEDA. Mesmo codigo do lab, onde create_iam_role = false
# porque o AWS Academy nao permite criar role.
########################################################################

variable "create_iam_role" {
  description = "Cria o OIDC provider do cluster e as roles de IRSA. true em prod."
  type        = bool
  default     = true
}

variable "eks_oidc_thumbprint" {
  description = "Thumbprint do CA raiz do issuer OIDC do EKS."
  type        = string
  default     = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
}

########################################################################
# Perfil dos recursos por servico (modules/service)
########################################################################

variable "rds_instance_class" {
  description = "Classe das instancias RDS."
  type        = string
  default     = "db.t3.small"
}

variable "rds_multi_az" {
  description = "Habilita Multi-AZ nas instancias RDS. true em prod."
  type        = bool
  default     = true
}

variable "rds_deletion_protection" {
  description = "Protege as instancias RDS contra delete acidental. true em prod."
  type        = bool
  default     = true
}

variable "rds_skip_final_snapshot" {
  description = "Pula o snapshot final no destroy do RDS. false em prod."
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Dias de retencao de backup automatico do RDS. 7 em prod."
  type        = number
  default     = 7
}

variable "dynamodb_point_in_time_recovery" {
  description = "Habilita PITR na tabela DynamoDB. true em prod."
  type        = bool
  default     = true
}

variable "redis_node_type" {
  description = "Tipo do node ElastiCache."
  type        = string
  default     = "cache.t3.small"
}

variable "redis_name" {
  description = "replication_group_id do Redis."
  type        = string
  default     = "tc-redis-prod"
}
