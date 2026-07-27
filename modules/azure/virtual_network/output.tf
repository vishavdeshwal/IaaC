output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "Virtual network ID."
}

output "vnet_name" {
  value       = azurerm_virtual_network.this.name
  description = "Virtual network name."
}

output "subnet_ids" {
  value       = { for k, s in azurerm_subnet.this : k => s.id }
  description = "Map of subnet name => subnet ID."
}
