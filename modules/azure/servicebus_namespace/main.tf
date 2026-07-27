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

resource "azurerm_servicebus_namespace" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  capacity            = var.sku == "Premium" ? var.capacity : 0

  tags = local.tags
}

resource "azurerm_servicebus_namespace_authorization_rule" "this" {
  for_each = var.authorization_rules

  name         = each.key
  namespace_id = azurerm_servicebus_namespace.this.id
  listen       = each.value.listen
  send         = each.value.send
  manage       = each.value.manage
}
