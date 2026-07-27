locals {
  name = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}-nsg"
  tags = merge(
    {
      Name        = local.name
      Environment = var.environment
      Project     = var.project
    },
    var.tags,
  )
}

resource "azurerm_network_security_group" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = var.security_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }

  tags = local.tags
}
