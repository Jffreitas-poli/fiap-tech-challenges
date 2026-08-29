variable "name" {
  description = "replication_group_id (ex.: tc-redis)."
  type        = string
}

variable "node_type" {
  description = "Tipo do node de cache."
  type        = string
  default     = "cache.t3.micro"
}

variable "engine_version" {
  description = "Versao do Redis."
  type        = string
  default     = "7.1"
}

variable "num_cache_clusters" {
  description = "Numero de nodes (1 = sem replica; >1 habilita failover automatico)."
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "Subnets privadas para o subnet group."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security Groups (liberar 6379 a partir do SG dos nodes EKS)."
  type        = list(string)
}

variable "transit_encryption_enabled" {
  description = "TLS no trafego. false para casar com redis:// dos configmaps da Fase 2."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags adicionais."
  type        = map(string)
  default     = {}
}
