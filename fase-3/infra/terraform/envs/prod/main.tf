########################################################################
# Composicao do ambiente PROD -- ToggleMaster Fase 3 (conta pessoal).
#
# Espelha envs/lab, mas: alta disponibilidade (NAT/RDS Multi-AZ, 3 AZs),
# instancias maiores, deletion protection ligada, e IAM proprio (roles
# criadas em fase-3/infra/bootstrap/prod, passadas via variaveis).
#
# NAO aplicado sob o AWS Academy. Ativacao: ver envs/prod/README.md.
#
# 1o apply:  terraform apply -target=module.networking -target=module.eks
#            terraform apply
########################################################################

locals {
  name = "tc"
  env  = "prod"

  common_tags = {
    Project     = "ToggleMaster"
    Phase       = "fase-3"
    Environment = local.env
    ManagedBy   = "terraform"
    Repo        = "NyEstevo/fiap-tech-challenges"
    Account     = var.account_id
  }

  rds_services = {
    auth      = { identifier = "tc-rds-auth-prod", db_name = "auth_db" }
    flag      = { identifier = "tc-rds-flag-prod", db_name = "flags_db" }
    targeting = { identifier = "tc-rds-targeting-prod", db_name = "targeting_db" }
  }

  ecr_repositories = [
    "tech-challenge/auth-image",
    "tech-challenge/flag-image",
    "tech-challenge/targeting-image",
    "tech-challenge/evaluation-image",
    "tech-challenge/analytics-image",
    "tech-challenge/auth-migrate-image",
  ]

  ingress_nginx_values_path = "${path.module}/../../../../../fase-2/ingress-nginx-values.yaml"
  gitops_root_app_path      = "${path.module}/../../../../gitops/root-app.yaml"
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

########################################################################
# ECR
########################################################################

module "ecr" {
  source = "../../modules/ecr"

  repositories = local.ecr_repositories
}

########################################################################
# RDS -- Multi-AZ + deletion protection
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

module "rds" {
  source   = "../../modules/rds"
  for_each = local.rds_services

  identifier              = each.value.identifier
  db_name                 = each.value.db_name
  username                = "postgres"
  instance_class          = var.rds_instance_class
  db_subnet_group_name    = aws_db_subnet_group.rds.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  multi_az                = true
  deletion_protection     = true
  skip_final_snapshot     = false
  backup_retention_period = 7
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
# Mensageria + store do analytics-service
########################################################################

module "sqs" {
  source = "../../modules/sqs"
  name   = var.sqs_queue_name
}

module "dynamodb" {
  source                 = "../../modules/dynamodb"
  name                   = var.dynamodb_table_name
  hash_key               = "event_id"
  point_in_time_recovery = true
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
    AWS_SQS_URL     = module.sqs.queue_url
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
    AWS_SQS_URL        = module.sqs.queue_url
    AWS_DYNAMODB_TABLE = module.dynamodb.table_name
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

# Application "app-of-apps" -- ArgoCD passa a sincronizar fase-3/gitops/.
# Em prod o ArgoCD deve seguir a branch 'main' (root-app.yaml usa 'lab' por
# padrao; sobrescreva o targetRevision antes de ativar prod, ou use um
# root-app-prod.yaml dedicado).
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
        kubectl get crd applications.argoproj.io >/dev/null 2>&1 && break
        echo "aguardando CRD do ArgoCD ($i/30)..."; sleep 10
      done
      kubectl apply -f ${local.gitops_root_app_path}
    EOT
  }

  depends_on = [module.addons]
}
