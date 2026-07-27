output "id" {
  value       = azurerm_network_interface.this.id
  description = "Network interface ID."
}

output "name" {
  value       = azurerm_network_interface.this.name
  description = "Network interface name."
}

output "private_ip_address" {
  value       = azurerm_network_interface.this.private_ip_address
  description = "Private IP assigned to the NIC."
}
