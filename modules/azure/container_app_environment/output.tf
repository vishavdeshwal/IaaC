output "id" {
  value       = azurerm_container_app_environment.this.id
  description = "Container App Environment ID."
}

output "name" {
  value       = azurerm_container_app_environment.this.name
  description = "Container App Environment name."
}

output "default_domain" {
  value       = azurerm_container_app_environment.this.default_domain
  description = "Default Domain of the Container App Environment."
}
