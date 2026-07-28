output "id" {
  value       = azurerm_managed_redis.this.id
  description = "Redis Cache ID."
}

output "name" {
  value       = azurerm_managed_redis.this.name
  description = "Redis Cache name."
}

output "primary_access_key" {
  value       = azurerm_managed_redis.this.default_database[0].primary_access_key
  sensitive   = true
  description = "Primary access key."
}
