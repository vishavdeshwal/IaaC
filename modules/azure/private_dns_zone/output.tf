output "id" {
  value       = azurerm_private_dns_zone.this.id
  description = "Private DNS zone ID."
}

output "name" {
  value       = azurerm_private_dns_zone.this.name
  description = "Private DNS zone name."
}
