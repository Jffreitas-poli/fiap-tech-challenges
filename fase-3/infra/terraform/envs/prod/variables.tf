variable "region" {
  description = "Regiao AWS."
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "ID da conta AWS de prod (conta pessoal)."
  type        = string
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

variable "rds_instance_class" {
  description = "Classe das instancias RDS."
  type        = string
  default     = "db.t3.small"
}

variable "redis_node_type" {
  description = "Tipo do node ElastiCache."
  type        = string
  default     = "cache.t3.small"
}

variable "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB do analytics-service."
  type        = string
  default     = "tc-dynamo-prod"
}

variable "sqs_queue_name" {
  description = "Nome da fila SQS."
  type        = string
  default     = "tc-sqs-prod"
}

variable "redis_name" {
  description = "replication_group_id do Redis."
  type        = string
  default     = "tc-redis-prod"
}
