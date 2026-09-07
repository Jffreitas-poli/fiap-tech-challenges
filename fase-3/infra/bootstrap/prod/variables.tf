variable "region" {
  description = "Regiao AWS do ambiente prod."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Bucket S3 do state de prod. Globalmente unico."
  type        = string
  default     = "tc-fiap-tfstate-prod"
}

variable "lock_table_name" {
  description = "Tabela DynamoDB de lock do state de prod."
  type        = string
  default     = "tc-fiap-tflock-prod"
}

variable "github_org" {
  description = "Org/owner do repositorio."
  type        = string
  default     = "NyEstevo"
}

variable "github_repo" {
  description = "Nome do repositorio."
  type        = string
  default     = "fiap-tech-challenges"
}

variable "create_oidc_provider" {
  description = "false se o OIDC provider do GitHub ja existir na conta."
  type        = bool
  default     = true
}
