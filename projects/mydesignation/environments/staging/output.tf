output "resource_group_name" {
  value       = module.resource_group.name
  description = "The resource group name."
}

output "vm_public_ip" {
  value       = module.pip_app.ip_address
  description = "Public IP of the staging-application VM."
}

output "vm_identity_principal_id" {
  value       = module.vm_app.identity_principal_id
  description = "System-assigned managed identity of the VM."
}

output "storage_blob_endpoint" {
  value       = module.storage.primary_blob_endpoint
  description = "Primary blob endpoint of the mydesignation storage account."
}

output "servicebus_endpoint" {
  value       = module.servicebus_namespace.endpoint
  description = "Service Bus namespace endpoint."
}

output "servicebus_queue_connection_strings" {
  value       = module.servicebus_queue.authorization_rule_connection_strings
  description = "Queue SAS connection strings (send-only / listen-only). Sensitive."
  sensitive   = true
}
