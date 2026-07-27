locals {
  name = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}-key"
  tags = merge(
    {
      Name        = local.name
      Environment = var.environment
      Project     = var.project
    },
    var.tags,
  )
}

resource "azurerm_ssh_public_key" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  public_key          = var.public_key
  tags                = local.tags
}
