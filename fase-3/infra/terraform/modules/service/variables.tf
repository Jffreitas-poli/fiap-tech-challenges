########################################################################
# Entrada principal: uma entrada de fase-3/services.yaml, tipada.
#
# O tipo abaixo NAO e decoracao. Ele e o unico ponto onde um erro de schema
# no services.yaml (campo faltando, tipo trocado) para no `plan` em vez de
# virar recurso errado no apply. Campos ausentes no yaml quando a flag esta
# desligada (db.name/seed/migrate no evaluation, por exemplo) sao declarados
# optional() e chegam como null.
########################################################################

variable "spec" {
  description = "Entrada de fase-3/services.yaml correspondente a ESTE servico."

  type = object({
    name     = string
    language = string
    port     = number
    path     = string

    http = object({
      enabled = bool
      route   = optional(string)
    })

    db = object({
      enabled = bool
      name    = optional(string)
      seed    = optional(bool, false)
      migrate = optional(string, "none")
    })

    cache = object({
      enabled = bool
    })

    queue = object({
      enabled = bool
      name    = optional(string)
      mode    = optional(string)
      keda    = optional(bool, false)
    })

    dynamodb = object({
      enabled = bool
      table   = optional(string)
    })
  })

  validation {
    condition     = !var.spec.db.enabled || var.spec.db.name != null
    error_message = "db.enabled = true exige db.name no services.yaml (db_name e ForceNew no RDS)."
  }

  validation {
    condition     = contains(["none", "app", "dedicated"], var.spec.db.migrate)
    error_message = "db.migrate deve ser 'app', 'dedicated' ou ausente."
  }

  validation {
    condition     = !var.spec.queue.enabled || contains(["producer", "consumer"], coalesce(var.spec.queue.mode, "?"))
    error_message = "queue.enabled = true exige queue.mode 'producer' ou 'consumer'."
  }

  validation {
    condition     = !var.spec.queue.enabled || var.spec.queue.name != null
    error_message = "queue.enabled = true exige queue.name."
  }

  validation {
    condition     = !var.spec.dynamodb.enabled || var.spec.dynamodb.table != null
    error_message = "dynamodb.enabled = true exige dynamodb.table."
  }
}

########################################################################
# Nomenclatura e identidade do ambiente
########################################################################

variable "name_prefix" {
  description = "Prefixo dos nomes de recurso (ex.: 'tc' -> tc-rds-auth)."
  type        = string
  default     = "tc"
}

variable "name_suffix" {
  description = "Sufixo dos nomes de recurso por ambiente. Vazio no lab; '-prod' em prod. NAO se aplica ao ECR (contas distintas ja isolam o nome)."
  type        = string
  default     = ""
}

variable "region" {
  description = "Regiao AWS. Usada para montar o ARN da fila na policy do KEDA."
  type        = string
}

variable "account_id" {
  description = "ID da conta AWS. Usado para montar o ARN da fila na policy do KEDA."
  type        = string
}

########################################################################
# RDS -- os SG e o subnet group sao compartilhados e vem do root
########################################################################

variable "rds_instance_class" {
  description = "Classe da instancia RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_db_subnet_group_name" {
  description = "DB subnet group compartilhado, criado no root."
  type        = string
  default     = null
}

variable "rds_vpc_security_group_ids" {
  description = "Security Groups da instancia RDS, criados no root."
  type        = list(string)
  default     = []
}

variable "rds_multi_az" {
  description = "Habilita Multi-AZ no RDS."
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Protege o RDS contra delete acidental."
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Pula o snapshot final no destroy do RDS."
  type        = bool
  default     = true
}

variable "rds_backup_retention_period" {
  description = "Dias de retencao de backup automatico do RDS."
  type        = number
  default     = 1
}

variable "rds_secret_recovery_window_days" {
  description = "Janela de recuperacao do secret de credenciais do RDS. 0 apaga imediatamente (lab)."
  type        = number
  default     = 0
}

########################################################################
# ECR
########################################################################

variable "ecr_image_tag_mutability" {
  description = "MUTABLE ou IMMUTABLE. O projeto publica com SemVer + SHA e exige IMMUTABLE."
  type        = string
  default     = "IMMUTABLE"
}

variable "ecr_scan_on_push" {
  description = "Habilita scan de vulnerabilidades no push."
  type        = bool
  default     = true
}

variable "ecr_keep_last" {
  description = "Imagens retidas por repositorio na lifecycle policy."
  type        = number
  default     = 10
}

variable "ecr_force_delete" {
  description = "Permite destroy do repositorio ECR mesmo com imagens dentro. Ver AVISO em main.tf."
  type        = bool
  default     = true
}

########################################################################
# DynamoDB
########################################################################

variable "dynamodb_point_in_time_recovery" {
  description = "Habilita PITR na tabela DynamoDB."
  type        = bool
  default     = false
}

########################################################################
# IAM / IRSA do KEDA
#
# lab (AWS Academy): create_iam_role = false. Nao ha permissao para criar
# role, nao ha IRSA, e o KEDA le a fila com as credenciais estaticas de
# sessao do Secret aws-session-creds (ver o patch do TriggerAuthentication em
# gitops/manifests/analytics/kustomization.yaml).
# prod: create_iam_role = true, IRSA por OIDC.
########################################################################

variable "create_iam_role" {
  description = "Cria a IAM role/policy de IRSA do KEDA. false sob o AWS Academy (lab), que nao permite criar role."
  type        = bool
  default     = false
}

variable "oidc_provider_arn" {
  description = "ARN do IAM OIDC provider do cluster EKS. Obrigatorio quando create_iam_role = true."
  type        = string
  default     = null
}

variable "oidc_issuer_url" {
  description = "URL do OIDC issuer do cluster EKS (com https://). Obrigatorio quando create_iam_role = true."
  type        = string
  default     = null
}

variable "keda_namespace" {
  description = "Namespace onde roda o operator do KEDA."
  type        = string
  default     = "keda"
}

variable "keda_service_account" {
  description = "ServiceAccount do operator do KEDA que assume a role de IRSA."
  type        = string
  default     = "keda-operator"
}
