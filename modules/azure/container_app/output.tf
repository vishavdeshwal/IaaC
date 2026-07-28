output "id" {
  value       = azurerm_container_app.this.id
  description = "Container App ID."
}

output "name" {
  value       = azurerm_container_app.this.name
  description = "Container App name."
}

output "latest_revision_name" {
  value       = azurerm_container_app.this.latest_revision_name
  description = "Name of the latest revision."
}

output "identity_principal_id" {
  value       = length(azurerm_container_app.this.identity) > 0 ? azurerm_container_app.this.identity[0].principal_id : null
  description = "Principal ID of the SystemAssigned Managed Identity."
}

output "ingress_fqdn" {
  value       = length(azurerm_container_app.this.ingress) > 0 ? azurerm_container_app.this.ingress[0].fqdn : null
  description = "FQDN of the ingress."
}
