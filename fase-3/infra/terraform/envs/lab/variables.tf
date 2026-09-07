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

variable "environment" {
  description = "Nome do ambiente. Entra nas tags (Environment) e no sufixo dos nomes de recurso. No lab e 'lab', que resolve para sufixo vazio -- os nomes em producao hoje sao tc-rds-auth, tc-sqs, tc-dynamo."
  type        = string
  default     = "lab"
}

variable "bootstrap_gitops_root_app" {
  description = "Aplica a root Application (app-of-apps) do ArgoCD via kubectl no apply. Default true; passe false so para pular esse passo (ex.: debug do resto do grafo)."
  type        = bool
  default     = true
}

variable "enable_external_secrets_creds" {
  description = "Cria os Secrets com as chaves da sessao: aws-static-creds (ns external-secrets) para o ClusterSecretStore do ESO e aws-session-creds (ns toggle) para os pods analytics/evaluation que falam direto com SQS/DynamoDB. Precisa das env vars AWS_* no ambiente do apply."
  type        = bool
  default     = true
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

########################################################################
# IAM
#
# O AWS Academy NAO permite criar IAM role. create_iam_role = false desliga
# o OIDC provider do cluster e o IRSA do KEDA; o KEDA passa a ler a fila com
# as credenciais estaticas de sessao do Secret aws-session-creds.
# Em prod o mesmo codigo roda com create_iam_role = true.
########################################################################

variable "create_iam_role" {
  description = "Cria o OIDC provider do cluster e as roles de IRSA. SEMPRE false no lab (AWS Academy nao permite criar role)."
  type        = bool
  default     = false
}

variable "eks_oidc_thumbprint" {
  description = "Thumbprint do CA raiz do issuer OIDC do EKS. So usado quando create_iam_role = true."
  type        = string
  default     = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
}

########################################################################
# Perfil dos recursos por servico (modules/service)
########################################################################

variable "rds_instance_class" {
  description = "Classe das instancias RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_multi_az" {
  description = "Habilita Multi-AZ nas instancias RDS. false no lab (custo)."
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Protege as instancias RDS contra delete acidental. false no lab (teardown rapido)."
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Pula o snapshot final no destroy do RDS. true no lab."
  type        = bool
  default     = true
}

variable "rds_backup_retention_period" {
  description = "Dias de retencao de backup automatico do RDS. 1 no lab."
  type        = number
  default     = 1
}

variable "dynamodb_point_in_time_recovery" {
  description = "Habilita PITR na tabela DynamoDB. false no lab (tabela de eventos, reprocessavel)."
  type        = bool
  default     = false
}

variable "redis_node_type" {
  description = "Tipo do node ElastiCache."
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_name" {
  description = "replication_group_id do Redis."
  type        = string
  default     = "tc-redis"
}
