########################################################################
# Composicao do ambiente PROD -- ToggleMaster Fase 3 (conta pessoal).
#
# Espelha envs/lab. A diferenca esta no provider (OIDC, conta propria) e no
# tfvars: alta disponibilidade (NAT/RDS Multi-AZ, 3 AZs), instancias maiores,
# deletion protection ligada e create_iam_role = true -- em prod o Terraform
# cria o OIDC provider do cluster e as roles de IRSA do KEDA, que o Academy
# nao permite no lab.
#
# NAO aplicado sob o AWS Academy. Ativacao: ver envs/prod/README.md.
#
# 1o apply:  terraform apply -target=module.networking -target=module.eks
#            terraform apply
########################################################################

locals {
  name = "tc"
  env  = var.environment

  common_tags = {
    Project     = "ToggleMaster"
    Phase       = "fase-3"
    Environment = local.env
    ManagedBy   = "terraform"
    Repo        = "Jffreitas-poli/fiap-tech-challenges"
    Account     = var.account_id
  }

  # Fonte unica -- mesmo arquivo lido por envs/lab.
  services = yamldecode(file("${path.module}/../../../../services.yaml")).services

  # Sufixo de ambiente: '-prod'. Da tc-rds-auth-prod, tc-sqs-prod,
  # tc-dynamo-prod, que sao os nomes ja declarados neste ambiente.
  name_suffix = local.env == "lab" ? "" : "-${local.env}"

  queue_consumer = one([for s in local.services : s.name if s.queue.enabled && try(s.queue.mode, "") == "consumer"])
  dynamodb_owner = one([for s in local.services : s.name if s.dynamodb.enabled])

  ingress_nginx_values_path = "${path.module}/../../../../../fase-2/ingress-nginx-values.yaml"
  # Manifesto de bootstrap do GitOps: o ApplicationSet `toggle-master` que
  # gera/adota as 7 Applications (substituiu a root-app app-of-apps).
  gitops_root_app_path = "${path.module}/../../../../gitops/applicationset.yaml"
}

########################################################################
# Networking -- NAT Gateway por AZ (HA)
########################################################################

module "networking" {
  source = "../../modules/networking"

  name                 = local.name
  env                  = local.env
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  eks_cluster_name     = var.cluster_name
  single_nat_gateway   = false
}

########################################################################
# EKS -- IAM proprio (bootstrap/prod), sem LabRole
########################################################################

module "eks" {
  source = "../../modules/eks"

  cluster_name         = var.cluster_name
  cluster_version      = var.cluster_version
  subnet_ids           = module.networking.private_subnet_ids
  public_subnet_ids    = module.networking.public_subnet_ids
  lab_role_arn         = var.eks_node_role_arn # fallback nao usado (roles abaixo tem prioridade)
  cluster_role_arn     = var.eks_cluster_role_arn
  node_role_arn        = var.eks_node_role_arn
  node_instance_types  = var.node_instance_types
  node_min             = 2
  node_desired         = 3
  node_max             = 6
  admin_principal_arns = var.admin_principal_arns
}

# Provider OIDC do cluster -- base do IRSA. Bloco identico ao de envs/lab; em
# prod create_iam_role = true e ele existe de fato.
resource "aws_iam_openid_connect_provider" "eks" {
  count = var.create_iam_role ? 1 : 0

  url             = module.eks.cluster_oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.eks_oidc_thumbprint]
}

########################################################################
# SG + subnet group compartilhados para RDS
########################################################################

resource "aws_db_subnet_group" "rds" {
  name       = "tc-rds-subnets-prod"
  subnet_ids = module.networking.private_subnet_ids

  tags = { Name = "tc-rds-subnets-prod" }
}

resource "aws_security_group" "rds" {
  name        = "tc-rds-sg-prod"
  description = "Permite 5432 a partir dos nodes EKS"
  vpc_id      = module.networking.vpc_id

  ingress {
    description     = "PostgreSQL do cluster EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    description = "Trafego de saida liberado (updates do PostgreSQL, DNS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "tc-rds-sg-prod" }
}

########################################################################
# UM servico = UMA instancia deste modulo. Bloco identico ao de envs/lab:
# tudo que difere entra por variavel.
########################################################################

module "service" {
  source   = "../../modules/service"
  for_each = { for s in local.services : s.name => s }

  spec        = each.value
  name_prefix = local.name
  name_suffix = local.name_suffix
  region      = var.region
  account_id  = var.account_id

  rds_instance_class          = var.rds_instance_class
  rds_db_subnet_group_name    = aws_db_subnet_group.rds.name
  rds_vpc_security_group_ids  = [aws_security_group.rds.id]
  rds_multi_az                = var.rds_multi_az
  rds_deletion_protection     = var.rds_deletion_protection
  rds_skip_final_snapshot     = var.rds_skip_final_snapshot
  rds_backup_retention_period = var.rds_backup_retention_period

  dynamodb_point_in_time_recovery = var.dynamodb_point_in_time_recovery

  create_iam_role   = var.create_iam_role
  oidc_provider_arn = one(aws_iam_openid_connect_provider.eks[*].arn)
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
}

########################################################################
# ElastiCache (Redis) -- replica + failover
########################################################################

resource "aws_security_group" "redis" {
  name        = "tc-redis-sg-prod"
  description = "Permite 6379 a partir dos nodes EKS"
  vpc_id      = module.networking.vpc_id

  ingress {
    description     = "Redis do cluster EKS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    description = "Trafego de saida liberado (DNS, telemetria)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "tc-redis-sg-prod" }
}

module "elasticache" {
  source = "../../modules/elasticache"

  name                       = var.redis_name
  node_type                  = var.redis_node_type
  num_cache_clusters         = 2
  subnet_ids                 = module.networking.private_subnet_ids
  security_group_ids         = [aws_security_group.redis.id]
  transit_encryption_enabled = false
}

########################################################################
# Secrets Manager :: segredos de aplicacao (nao-RDS)
########################################################################

resource "random_password" "auth_master_key" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "auth_app" {
  name                    = "tc-auth-app-prod"
  description             = "Segredos de aplicacao do auth-service (prod)."
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "auth_app" {
  secret_id     = aws_secretsmanager_secret.auth_app.id
  secret_string = jsonencode({ MASTER_KEY = random_password.auth_master_key.result })
}

resource "random_password" "evaluation_api_key" {
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "evaluation_app" {
  name                    = "tc-evaluation-app-prod"
  description             = "Segredos + config runtime do evaluation-service (prod)."
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "evaluation_app" {
  secret_id = aws_secretsmanager_secret.evaluation_app.id
  secret_string = jsonencode({
    SERVICE_API_KEY = random_password.evaluation_api_key.result
    REDIS_URL       = module.elasticache.redis_url
    AWS_SQS_URL     = module.service[local.queue_consumer].queue_url
    AWS_REGION      = var.region
  })
}

resource "aws_secretsmanager_secret" "analytics_app" {
  name                    = "tc-analytics-app-prod"
  description             = "Config runtime do analytics-service (prod)."
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "analytics_app" {
  secret_id = aws_secretsmanager_secret.analytics_app.id
  secret_string = jsonencode({
    AWS_SQS_URL        = module.service[local.queue_consumer].queue_url
    AWS_DYNAMODB_TABLE = module.service[local.dynamodb_owner].dynamodb_table_name
    AWS_REGION         = var.region
  })
}

########################################################################
# Add-ons de cluster (Helm) + bootstrap do GitOps
########################################################################

module "addons" {
  source = "../../modules/addons"

  ingress_nginx_values_path = local.ingress_nginx_values_path

  depends_on = [module.eks]
}

# No DESTROY, apaga o Service do ingress-nginx antes de derrubar os add-ons
# (libera o NLB e evita DependencyViolation na VPC).
resource "null_resource" "ingress_lb_cleanup" {
  triggers = {
    cluster = var.cluster_name
    region  = var.region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws eks update-kubeconfig --name ${self.triggers.cluster} --region ${self.triggers.region} 2>/dev/null || exit 0
      kubectl delete svc -n ingress-nginx ingress-nginx-controller --ignore-not-found --wait --timeout=300s || true
    EOT
  }

  depends_on = [module.addons]
}

# ApplicationSet "toggle-master" -- ArgoCD passa a sincronizar fase-3/gitops/.
# Em prod o ArgoCD deve seguir a branch 'main' (applicationset.yaml usa 'lab'
# em revision/targetRevision por padrao; sobrescreva antes de ativar prod, ou
# use um applicationset-prod.yaml dedicado).
resource "null_resource" "root_app" {
  count = var.bootstrap_gitops_root_app ? 1 : 0

  triggers = {
    cluster      = var.cluster_name
    region       = var.region
    manifest_sha = filesha256(local.gitops_root_app_path)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      aws eks update-kubeconfig --name ${self.triggers.cluster} --region ${self.triggers.region}
      for i in $(seq 1 30); do
        kubectl get crd applicationsets.argoproj.io >/dev/null 2>&1 && break
        echo "aguardando CRD do ArgoCD ($i/30)..."; sleep 10
      done
      kubectl apply -f ${local.gitops_root_app_path}
    EOT
  }

  depends_on = [module.addons]
}
