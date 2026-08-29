variable "region" {
  description = "Regiao AWS."
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "ID da conta AWS (usado para montar ARNs)."
  type        = string
  default     = "361075236043"
}

variable "bootstrap_gitops_root_app" {
  description = "Cria o kubernetes_manifest da root Application do ArgoCD. Deixe false no 1o apply/CI (o cluster ainda nao existe); ligue depois que o cluster + ArgoCD estiverem no ar."
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "Nome do cluster EKS."
  type        = string
  default     = "tc-eks"
}

variable "cluster_version" {
  description = "Versao do Kubernetes."
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR da VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability Zones."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets publicas."
  type        = list(string)
  default     = ["10.20.0.0/20", "10.20.16.0/20"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas."
  type        = list(string)
  default     = ["10.20.128.0/20", "10.20.144.0/20"]
}

variable "lab_role_name" {
  description = "Nome da role do AWS Academy usada pelo cluster e pelos nodes."
  type        = string
  default     = "LabRole"
}

variable "admin_principal_arns" {
  description = "ARNs de IAM que recebem cluster-admin via EKS access entries. Vazio = so o criador."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  description = "Tipos de instancia dos nodes."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "rds_instance_class" {
  description = "Classe das instancias RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "redis_node_type" {
  description = "Tipo do node ElastiCache."
  type        = string
  default     = "cache.t3.micro"
}

variable "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB do analytics-service (casa com o configmap da Fase 2)."
  type        = string
  default     = "tc-dynamo"
}

variable "sqs_queue_name" {
  description = "Nome da fila SQS."
  type        = string
  default     = "tc-sqs"
}

variable "redis_name" {
  description = "replication_group_id do Redis."
  type        = string
  default     = "tc-redis"
}
