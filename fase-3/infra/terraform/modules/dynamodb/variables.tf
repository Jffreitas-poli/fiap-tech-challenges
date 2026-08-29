variable "name" {
  description = "Nome da tabela (ex.: tc-dynamo)."
  type        = string
}

variable "hash_key" {
  description = "Chave de particao."
  type        = string
  default     = "event_id"
}

variable "billing_mode" {
  description = "PAY_PER_REQUEST ou PROVISIONED."
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "ttl_attribute" {
  description = "Atributo usado como TTL (expiracao automatica de itens). Vazio desativa o TTL."
  type        = string
  default     = "expires_at"
}

variable "enable_gsi" {
  description = "Cria um GSI por flag_name (forward-looking; o codigo atual do analytics nao usa)."
  type        = bool
  default     = true
}

variable "point_in_time_recovery" {
  description = "Habilita PITR."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags adicionais."
  type        = map(string)
  default     = {}
}
