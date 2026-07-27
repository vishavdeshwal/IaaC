output "state_storage_account_name" {
  value       = azurerm_storage_account.state.name
  description = "Copy this into the backend \"azurerm\" block (storage_account_name) of every environment."
}

output "state_container_name" {
  value       = azurerm_storage_container.state.name
  description = "Container name for the backend blocks (container_name)."
}

output "state_resource_group_name" {
  value       = var.resource_group_name
  description = "Resource group for the backend blocks (resource_group_name)."
}
