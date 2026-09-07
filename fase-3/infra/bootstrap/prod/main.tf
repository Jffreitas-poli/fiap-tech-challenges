########################################################################
# Bootstrap do ambiente PROD (conta pessoal) -- rodar UMA vez, localmente,
# com credenciais de admin da conta. STATE LOCAL de proposito.
#
# NAO se aplica ao AWS Academy (Vocareum bloqueia iam:Create*). Este
# diretorio so e usado quando o prod roda numa conta AWS real.
#
# Cria:
#   - bucket S3 + tabela DynamoDB de lock do state de prod
#   - OIDC provider do GitHub + IAM Role assumida pelos workflows (main)
#   - IAM Roles do control plane e dos nodes do EKS (o modulo eks nao cria IAM)
#
#   cd fase-3/infra/bootstrap/prod
#   terraform init && terraform apply
#   # depois: setar vars.PROD_AWS_ROLE_ARN no GitHub com o output github_actions_role_arn
########################################################################

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "ToggleMaster"
      Phase       = "fase-3"
      Environment = "prod"
      ManagedBy   = "terraform"
      Repo        = "${var.github_org}/${var.github_repo}"
      Component   = "prod-bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

########################################################################
# Backend remoto do state de prod
########################################################################

resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tflock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

########################################################################
# OIDC + IAM Role dos workflows (GitHub Actions -> AWS, sem chaves)
########################################################################

module "github_actions" {
  source = "../../terraform/modules/iam_oidc_github"

  github_org           = var.github_org
  github_repo          = var.github_repo
  allowed_branches     = ["main"]
  allow_pull_requests  = true
  role_name            = "tc-github-actions-prod"
  create_oidc_provider = var.create_oidc_provider
  # least privilege: policy dedicada (abaixo), NUNCA AdministratorAccess
  managed_policy_arns = [aws_iam_policy.gha_infra.arn]
}

# Escopo minimo para o plan/apply da infra do ToggleMaster. Servicos de
# rede/EKS exigem acoes ec2:* amplas por natureza; o restante e limitado
# aos servicos do projeto. Sem iam:* alem de PassRole das roles do EKS.
resource "aws_iam_policy" "gha_infra" {
  name        = "tc-github-actions-prod-infra"
  description = "Permissoes de provisionamento da infra da Fase 3 (least privilege)."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CoreProvisioning"
        Effect = "Allow"
        Action = [
          "ec2:*", "elasticloadbalancing:*", "autoscaling:*",
          "eks:*", "rds:*", "elasticache:*", "sqs:*", "dynamodb:*",
          "ecr:*", "secretsmanager:*", "kms:Describe*", "kms:List*",
          "logs:*", "cloudwatch:*", "application-autoscaling:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformBackend"
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
      },
      {
        Sid      = "TerraformLock"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = aws_dynamodb_table.tflock.arn
      },
      {
        Sid    = "PassEksRoles"
        Effect = "Allow"
        Action = ["iam:PassRole", "iam:GetRole"]
        Resource = [
          aws_iam_role.eks_cluster.arn,
          aws_iam_role.eks_node.arn
        ]
      },
      {
        Sid    = "ReadIamForEks"
        Effect = "Allow"
        Action = [
          "iam:ListRoles", "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfiles", "iam:ListInstanceProfilesForRole",
          "iam:GetInstanceProfile", "iam:GetOpenIDConnectProvider",
          "iam:GetRolePolicy", "iam:ListRolePolicies",
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
      }
    ]
  })
}

########################################################################
# IAM Roles do EKS (o modulo eks nao cria IAM -- passa-se os ARNs a ele)
########################################################################

data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "tc-eks-cluster-prod"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
  ])
  role       = aws_iam_role.eks_cluster.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "tc-eks-node-prod"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])
  role       = aws_iam_role.eks_node.name
  policy_arn = each.value
}
