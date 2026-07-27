output "id" {
  value       = azurerm_network_security_group.this.id
  description = "Network security group ID."
}

output "name" {
  value       = azurerm_network_security_group.this.name
  description = "Network security group name."
}
