output "id" {
  value       = azurerm_public_ip.this.id
  description = "Public IP resource ID."
}

output "name" {
  value       = azurerm_public_ip.this.name
  description = "Public IP resource name."
}

output "ip_address" {
  value       = azurerm_public_ip.this.ip_address
  description = "The allocated public IP address."
}
