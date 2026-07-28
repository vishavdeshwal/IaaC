output "id" {
  value       = azurerm_postgresql_flexible_server.this.id
  description = "PostgreSQL Flexible Server ID."
}

output "name" {
  value       = azurerm_postgresql_flexible_server.this.name
  description = "PostgreSQL Flexible Server name."
}

output "fqdn" {
  value       = azurerm_postgresql_flexible_server.this.fqdn
  description = "Fully qualified domain name of the PostgreSQL Flexible Server."
}
