########################################################################
# Composicao do ambiente LAB -- ToggleMaster Fase 3
#
# Um unico root module chama todos os modulos-filho. O Terraform resolve
# a ordem pelo grafo de dependencias. No PRIMEIRO apply, encene:
#   terraform apply -target=module.networking -target=module.eks
#   terraform apply
########################################################################

locals {
  name = "tc"
  env  = "lab"

  common_tags = {
    Project     = "ToggleMaster"
    Phase       = "fase-3"
    Environment = local.env
    ManagedBy   = "terraform"
    Repo        = "NyEstevo/fiap-tech-challenges"
    Account     = var.account_id
  }

  # database-per-service: identifier da instancia RDS -> nome do banco
  rds_services = {
    auth      = { identifier = "tc-rds-auth", db_name = "auth_db" }
    flag      = { identifier = "tc-rds-flag", db_name = "flags_db" }
    targeting = { identifier = "tc-rds-targeting", db_name = "targeting_db" }
  }

  ecr_repositories = [
    "tech-challenge/auth-image",
    "tech-challenge/flag-image",
    "tech-challenge/targeting-image",
    "tech-challenge/evaluation-image",
    "tech-challenge/analytics-image",
    # imagem de migration do auth (golang-migrate). flag/targeting rodam a
    # migration (Alembic) a partir da propria imagem da aplicacao.
    "tech-challenge/auth-migrate-image",
  ]

  ingress_nginx_values_path = "${path.module}/../../../../../fase-2/ingress-nginx-values.yaml"
  gitops_root_app_path      = "${path.module}/../../../../gitops/root-app.yaml"
}

data "aws_iam_role" "lab" {
  name = var.lab_role_name
}

########################################################################
# Networking
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
  single_nat_gateway   = true
}

########################################################################
# EKS
########################################################################

module "eks" {
  source = "../../modules/eks"

  cluster_name         = var.cluster_name
  cluster_version      = var.cluster_version
  subnet_ids           = module.networking.private_subnet_ids
  public_subnet_ids    = module.networking.public_subnet_ids
  lab_role_arn         = data.aws_iam_role.lab.arn
  node_instance_types  = var.node_instance_types
  node_min             = 1
  node_desired         = 2
  node_max             = 4
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
# SG + subnet group compartilhados para RDS
########################################################################

resource "aws_db_subnet_group" "rds" {
  name       = "tc-rds-subnets"
  subnet_ids = module.networking.private_subnet_ids

  tags = { Name = "tc-rds-subnets" }
}

resource "aws_security_group" "rds" {
  name        = "tc-rds-sg"
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "tc-rds-sg" }
}

module "rds" {
  source   = "../../modules/rds"
  for_each = local.rds_services

  identifier             = each.value.identifier
  db_name                = each.value.db_name
  username               = "postgres"
  instance_class         = var.rds_instance_class
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az               = false
  deletion_protection    = false
  skip_final_snapshot    = true
}

########################################################################
# ElastiCache (Redis) para o evaluation-service
########################################################################

resource "aws_security_group" "redis" {
  name        = "tc-redis-sg"
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "tc-redis-sg" }
}

module "elasticache" {
  source = "../../modules/elasticache"

  name                       = var.redis_name
  node_type                  = var.redis_node_type
  num_cache_clusters         = 1
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
  source   = "../../modules/dynamodb"
  name     = var.dynamodb_table_name
  hash_key = "event_id"
}

########################################################################
# Secrets Manager :: segredos de aplicacao (nao-RDS)
# O modulo rds ja publica tc-rds-<svc>-credentials. Aqui ficam os
# segredos de app: MASTER_KEY (auth) e SERVICE_API_KEY (evaluation).
# O External Secrets Operator le estes + os do rds e materializa o
# Secret <svc>-secret no namespace toggle.
########################################################################

resource "random_password" "auth_master_key" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "auth_app" {
  name                    = "tc-auth-app"
  description             = "Segredos de aplicacao do auth-service (ToggleMaster)."
  recovery_window_in_days = 0
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
  name                    = "tc-evaluation-app"
  description             = "Segredos + config runtime do evaluation-service (ToggleMaster)."
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "evaluation_app" {
  secret_id = aws_secretsmanager_secret.evaluation_app.id
  # SERVICE_API_KEY e segredo; REDIS_URL/AWS_* sao config de ambiente derivada
  # dos modulos -- centralizada aqui para o configmap so guardar valor estatico.
  secret_string = jsonencode({
    SERVICE_API_KEY = random_password.evaluation_api_key.result
    REDIS_URL       = module.elasticache.redis_url
    AWS_SQS_URL     = module.sqs.queue_url
    AWS_REGION      = var.region
  })
}

resource "aws_secretsmanager_secret" "analytics_app" {
  name                    = "tc-analytics-app"
  description             = "Config runtime do analytics-service (ToggleMaster)."
  recovery_window_in_days = 0
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
# Add-ons de cluster (Helm)  +  bootstrap do GitOps
########################################################################

module "addons" {
  source = "../../modules/addons"

  ingress_nginx_values_path = local.ingress_nginx_values_path

  depends_on = [module.eks]
}

# No DESTROY, roda ANTES de derrubar os add-ons: apaga o Service do
# ingress-nginx para a AWS liberar o NLB. Sem isso, o Load Balancer +
# security groups ficam orfaos e travam a exclusao da VPC (DependencyViolation).
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

# Application "app-of-apps" -- ArgoCD passa a sincronizar fase-3/gitops/
#
# Aplicada via local-exec (kubectl), NAO via kubernetes_manifest: aquele
# recurso exige conexao viva com a API do cluster ja no `plan`, o que quebra
# o 1o apply de um ambiente vazio e o `tf-plan` do CI. O null_resource so
# executa no apply, depois que os add-ons (inclusive ArgoCD + CRDs) subiram.
# Idempotente (kubectl apply); re-roda quando root-app.yaml muda.
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
