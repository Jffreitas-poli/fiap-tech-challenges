variable "github_org" {
  description = "Organizacao/owner do repositorio no GitHub."
  type        = string
}

variable "github_repo" {
  description = "Nome do repositorio."
  type        = string
}

variable "allowed_branches" {
  description = "Branches autorizadas a assumir a role."
  type        = list(string)
  default     = ["main"]
}

variable "allow_pull_requests" {
  description = "Se true, tambem autoriza o contexto pull_request (para tf-plan em PR)."
  type        = bool
  default     = true
}

variable "role_name" {
  description = "Nome da IAM Role."
  type        = string
  default     = "gha-toggle-master-infra"
}

variable "managed_policy_arns" {
  description = "Policies gerenciadas anexadas a role."
  type        = list(string)
  default     = []
}

variable "create_oidc_provider" {
  description = "Se false, assume que o OIDC provider do GitHub ja existe na conta."
  type        = bool
  default     = true
}
