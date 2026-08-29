########################################################################
# Bootstrap do backend remoto do Terraform (rodar UMA vez).
#
# Cria o bucket S3 e a tabela DynamoDB usados como state + lock por
# todas as composições em fase-3/infra/terraform/envs/*.
#
# Este diretório usa STATE LOCAL de propósito (não há backend "s3" aqui):
# ele é o que cria o backend. Commite apenas os .tf, nunca o tfstate.
#
#   cd fase-3/infra/bootstrap
#   terraform init
#   terraform apply
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
      Environment = "shared"
      ManagedBy   = "terraform"
      Repo        = "NyEstevo/fiap-tech-challenges"
      Component   = "tf-backend-bootstrap"
    }
  }
}

resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  # Protege contra terraform destroy acidental do backend.
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
      sse_algorithm = "AES256"
    }
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
