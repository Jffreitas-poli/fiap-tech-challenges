terraform {
  backend "s3" {
    bucket         = "tc-fiap-tfstate-047719652987"
    key            = "fase-3/lab/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "tc-fiap-tflock"
    encrypt        = true
  }
}
