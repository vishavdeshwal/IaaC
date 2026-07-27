output "id" {
  value       = azurerm_storage_account.this.id
  description = "Storage account ID."
}

output "name" {
  value       = azurerm_storage_account.this.name
  description = "Storage account name."
}

output "primary_blob_endpoint" {
  value       = azurerm_storage_account.this.primary_blob_endpoint
  description = "Primary blob service endpoint."
}

output "primary_queue_endpoint" {
  value       = azurerm_storage_account.this.primary_queue_endpoint
  description = "Primary queue service endpoint."
}

output "container_ids" {
  value       = { for k, c in azurerm_storage_container.this : k => c.id }
  description = "Map of container name => ID."
}

output "queue_ids" {
  value       = { for k, q in azurerm_storage_queue.this : k => q.id }
  description = "Map of queue name => ID."
}
