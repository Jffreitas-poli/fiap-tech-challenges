# Valores do ambiente prod (conta pessoal). Copie para terraform.tfvars e ajuste.
# CIDRs nao podem colidir com o lab (10.20.0.0/16).

region      = "us-east-1"
account_id  = "047719652987"
environment = "prod"

# Outputs de fase-3/infra/bootstrap/prod:
eks_cluster_role_arn = "arn:aws:iam::047719652987:role/tc-eks-cluster-prod"
eks_node_role_arn    = "arn:aws:iam::047719652987:role/tc-eks-node-prod"

cluster_name    = "tc-eks-prod"
cluster_version = "1.31"

vpc_cidr             = "10.30.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.30.0.0/20", "10.30.16.0/20", "10.30.32.0/20"]
private_subnet_cidrs = ["10.30.128.0/20", "10.30.144.0/20", "10.30.160.0/20"]

admin_principal_arns = ["arn:aws:iam::047719652987:user/terraform"]

# Conta propria: o Terraform cria o OIDC provider do cluster e as roles de
# IRSA do KEDA. No lab isto e false (o AWS Academy nao permite criar role).
create_iam_role = true

node_instance_types = ["t3.large"]

rds_instance_class          = "db.t3.small"
rds_multi_az                = true
rds_deletion_protection     = true
rds_skip_final_snapshot     = false
rds_backup_retention_period = 7

dynamodb_point_in_time_recovery = true

redis_node_type = "cache.t3.small"
redis_name      = "tc-redis-prod"

# Os nomes da fila SQS e da tabela DynamoDB deixaram de ser variaveis: vem de
# queue.name / dynamodb.table em fase-3/services.yaml, com o sufixo do
# ambiente -- tc-sqs-prod, tc-dynamo-prod.
