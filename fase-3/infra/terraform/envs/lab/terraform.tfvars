region          = "us-east-2"
account_id      = "047719652987"
cluster_name    = "tc-eks"
cluster_version = "1.30"

vpc_cidr             = "10.20.0.0/16"
azs                  = ["us-east-2a", "us-east-2b"]
public_subnet_cidrs  = ["10.20.0.0/20", "10.20.16.0/20"]
private_subnet_cidrs = ["10.20.128.0/20", "10.20.144.0/20"]

lab_role_name = "LabRole"

admin_principal_arns = [
  "arn:aws:iam::047719652987:role/LabRole",
]

node_instance_types = ["t3.medium"]
rds_instance_class  = "db.t3.micro"
redis_node_type     = "cache.t3.micro"

dynamodb_table_name = "tc-dynamo"
sqs_queue_name      = "tc-sqs"
redis_name          = "tc-redis"
