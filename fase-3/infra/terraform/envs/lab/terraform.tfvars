region          = "us-east-1"
account_id      = "361075236043"
cluster_name    = "tc-eks"
cluster_version = "1.31"

vpc_cidr             = "10.20.0.0/16"
azs                  = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.20.0.0/20", "10.20.16.0/20"]
private_subnet_cidrs = ["10.20.128.0/20", "10.20.144.0/20"]

lab_role_name = "LabRole"

admin_principal_arns = [] # NAO inclua a role dos nodes (LabRole) aqui -- colide com o entry EC2_LINUX

node_instance_types = ["t3.medium"]
rds_instance_class  = "db.t3.micro"
redis_node_type     = "cache.t3.micro"

dynamodb_table_name = "tc-dynamo"
sqs_queue_name      = "tc-sqs"
redis_name          = "tc-redis"
