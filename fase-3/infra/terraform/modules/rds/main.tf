########################################################################
# modulo rds
# Uma instancia PostgreSQL privada por microsservico (database-per-service).
# A senha e gerada pelo Terraform e guardada no Secrets Manager -- nunca
# fica em tfvars nem em GitHub Secrets.
########################################################################

resource "random_password" "this" {
  length  = 24
  special = false
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.username
  password = random_password.this.result
  port     = 5432

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = var.backup_retention_period
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.identifier}-final"
  apply_immediately          = true
  auto_minor_version_upgrade = true

  tags = merge(var.tags, { Name = var.identifier })
}

resource "aws_secretsmanager_secret" "this" {
  name        = "${var.identifier}-credentials"
  description = "Credenciais do RDS ${var.identifier} (ToggleMaster)."
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    username = var.username
    password = random_password.this.result
    host     = aws_db_instance.this.address
    port     = 5432
    dbname   = var.db_name
    url      = "postgres://${var.username}:${random_password.this.result}@${aws_db_instance.this.address}:5432/${var.db_name}"
  })
}
