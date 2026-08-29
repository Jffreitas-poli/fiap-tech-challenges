terraform {
  backend "s3" {
    bucket         = "tc-fiap-tfstate-361075236043"
    key            = "fase-3/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tc-fiap-tflock"
    encrypt        = true
  }
}
