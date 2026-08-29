########################################################################
# modulo dynamodb
# Tabela de eventos de uso do analytics-service.
########################################################################

resource "aws_dynamodb_table" "this" {
  name         = var.name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key

  attribute {
    name = var.hash_key
    type = "S"
  }

  dynamic "attribute" {
    for_each = var.enable_gsi ? [1] : []
    content {
      name = "flag_name"
      type = "S"
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.enable_gsi ? [1] : []
    content {
      name            = "flag_name-index"
      hash_key        = "flag_name"
      projection_type = "ALL"
    }
  }

  dynamic "ttl" {
    for_each = var.ttl_attribute == "" ? [] : [1]
    content {
      attribute_name = var.ttl_attribute
      enabled        = true
    }
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  tags = merge(var.tags, { Name = var.name })
}
