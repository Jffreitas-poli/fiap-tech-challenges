terraform {
  backend "s3" {
    bucket         = "tc-fiap-tfstate-prod"
    key            = "fase-3/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tc-fiap-tflock-prod"
    encrypt        = true
  }
}
