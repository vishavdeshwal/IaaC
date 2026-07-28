resource "azurerm_managed_redis" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku_name                      = var.sku_name
  public_network_access         = var.public_network_access_enabled ? "Enabled" : "Disabled"
  
  default_database {
    access_keys_authentication_enabled = true
  }

  tags = var.tags
}
