########################################################################
# modulo elasticache
# Redis (replication group) para o evaluation-service. Non-TLS por padrao
# para casar com REDIS_URL=redis://... do configmap ja em producao.
########################################################################

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.name
  description          = "ToggleMaster evaluation-service cache"

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  num_cache_clusters         = var.num_cache_clusters
  automatic_failover_enabled = var.num_cache_clusters > 1
  multi_az_enabled           = var.num_cache_clusters > 1

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = var.security_group_ids

  transit_encryption_enabled = var.transit_encryption_enabled
  at_rest_encryption_enabled = true

  apply_immediately = true

  tags = merge(var.tags, { Name = var.name })
}
