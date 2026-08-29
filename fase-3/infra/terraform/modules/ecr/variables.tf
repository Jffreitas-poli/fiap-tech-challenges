variable "repositories" {
  description = "Nomes dos repositorios ECR a criar (um por microsservico)."
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "MUTABLE ou IMMUTABLE. Fase 2 usa tags imutaveis com SemVer."
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Habilita scan de vulnerabilidades no push."
  type        = bool
  default     = true
}

variable "keep_last" {
  description = "Quantidade de imagens a reter por repositorio (lifecycle policy)."
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "Permite destroy do repositorio mesmo com imagens (util no ambiente lab)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags adicionais."
  type        = map(string)
  default     = {}
}
