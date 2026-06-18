resource "aws_dynamodb_table" "table" {
  name                        = var.name
  billing_mode                = var.billing_mode
  hash_key                    = var.hash_key
  range_key                   = var.range_key
  deletion_protection_enabled = var.deletion_protection_enabled
  table_class                 = var.table_class
  stream_enabled              = var.stream_enabled
  stream_view_type            = var.stream_view_type

  # Dynamic key and index attributes
  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  # Dynamic GSIs
  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = lookup(global_secondary_index.value, "range_key", null)
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = lookup(global_secondary_index.value, "non_key_attributes", null)
      read_capacity      = lookup(global_secondary_index.value, "read_capacity", 0)
      write_capacity     = lookup(global_secondary_index.value, "write_capacity", 0)
    }
  }

  tags = {
    Name        = var.name
    Environment = var.environment
    Project     = var.project
  }
}
