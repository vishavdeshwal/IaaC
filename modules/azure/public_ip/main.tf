locals {
  name = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}-pip"
  tags = merge(
    {
      Name        = local.name
      Environment = var.environment
      Project     = var.project
    },
    var.tags,
  )
}

resource "azurerm_public_ip" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = var.allocation_method
  sku                 = var.sku
  tags                = local.tags
}
