locals {
  name = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}-nic"
  tags = merge(
    {
      Name        = local.name
      Environment = var.environment
      Project     = var.project
    },
    var.tags,
  )
}

resource "azurerm_network_interface" "this" {
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = var.ip_configuration_name
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address_allocation
    private_ip_address            = var.private_ip_address_allocation == "Static" ? var.private_ip_address : null
    public_ip_address_id          = var.public_ip_address_id
    primary                       = true
  }

  tags = local.tags
}

# NIC-level NSG association (created only when an NSG id is supplied)
resource "azurerm_network_interface_security_group_association" "this" {
  count = var.network_security_group_id != null ? 1 : 0

  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = var.network_security_group_id
}
