output "id" {
  value       = azurerm_private_endpoint.this.id
  description = "Private endpoint ID."
}

output "name" {
  value       = azurerm_private_endpoint.this.name
  description = "Private endpoint name."
}

output "custom_dns_configs" {
  value       = azurerm_private_endpoint.this.custom_dns_configs
  description = "Custom DNS configurations."
}
