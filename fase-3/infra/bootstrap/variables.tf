variable "region" {
  description = "Regiao AWS onde o bucket de state e a tabela de lock serao criados."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Nome do bucket S3 do Terraform state. Precisa ser globalmente unico."
  type        = string
  default     = "tc-fiap-tfstate-361075236043"
}

variable "lock_table_name" {
  description = "Nome da tabela DynamoDB usada para state locking."
  type        = string
  default     = "tc-fiap-tflock"
}
