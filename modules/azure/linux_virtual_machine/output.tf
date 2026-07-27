output "id" {
  value       = azurerm_linux_virtual_machine.this.id
  description = "Virtual machine ID."
}

output "name" {
  value       = azurerm_linux_virtual_machine.this.name
  description = "Virtual machine name."
}

output "private_ip_address" {
  value       = azurerm_linux_virtual_machine.this.private_ip_address
  description = "Primary private IP address."
}

output "public_ip_address" {
  value       = azurerm_linux_virtual_machine.this.public_ip_address
  description = "Primary public IP address (if any)."
}

output "identity_principal_id" {
  value       = try(azurerm_linux_virtual_machine.this.identity[0].principal_id, null)
  description = "System-assigned managed identity principal ID."
}
