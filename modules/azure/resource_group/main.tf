locals {
  name = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}"
  tags = merge(
    {
      Name        = local.name
      Environment = var.environment
      Project     = var.project
    },
    var.tags,
  )
}

resource "azurerm_resource_group" "this" {
  name     = local.name
  location = var.location
  tags     = local.tags
}
