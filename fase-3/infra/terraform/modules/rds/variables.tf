variable "identifier" {
  description = "Identificador da instancia RDS (ex.: tc-rds-auth)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.identifier))
    error_message = "identifier deve comecar com letra minuscula, conter apenas [a-z0-9-] e ter no maximo 63 caracteres."
  }
}

variable "db_name" {
  description = "Nome do banco inicial (ex.: auth_db)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name deve ser um identificador SQL valido (letras, digitos e _; nao comecar com digito)."
  }
}

variable "username" {
  description = "Usuario master."
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Versao do PostgreSQL. Precisa existir na regiao (aws rds describe-db-engine-versions --engine postgres)."
  type        = string
  default     = "16.9"
}

variable "secret_recovery_window_days" {
  description = "Janela de recuperacao do secret no Secrets Manager. 0 = apaga imediatamente no destroy (lab)."
  type        = number
  default     = 0
}

variable "instance_class" {
  description = "Classe da instancia."
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = can(regex("^db\\.", var.instance_class))
    error_message = "instance_class deve comecar com 'db.' (ex.: db.t3.micro)."
  }
}

variable "allocated_storage" {
  description = "Armazenamento inicial (GiB)."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Teto de autoscaling de storage (GiB). 0 desliga."
  type        = number
  default     = 50
}

variable "db_subnet_group_name" {
  description = "Nome do DB subnet group (criado no root, compartilhado pelas 3 instancias)."
  type        = string
}

variable "vpc_security_group_ids" {
  description = "Security Groups da instancia (liberar 5432 a partir do SG dos nodes EKS)."
  type        = list(string)
}

variable "multi_az" {
  description = "Habilita Multi-AZ."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Protege contra delete acidental."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Pula snapshot final no destroy (true no lab)."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Dias de retencao de backup automatico."
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags adicionais."
  type        = map(string)
  default     = {}
}
