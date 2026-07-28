# Add outputs here as modules are added to prod (see environments/staging/output.tf).
output "acr_login_server" {
  value       = module.acr.login_server
  description = "ACR Login Server URL"
}

output "acr_admin_username" {
  value       = module.acr.admin_username
  description = "ACR Admin Username"
}

output "acr_admin_password" {
  value       = module.acr.admin_password
  description = "ACR Admin Password"
  sensitive   = true
}

output "db_fqdn" {
  value       = module.db.fqdn
  description = "PostgreSQL Flexible Server FQDN"
}

output "redis_name" {
  value       = module.cache.name
  description = "Redis Cache Name"
}

output "redis_primary_access_key" {
  value       = module.cache.primary_access_key
  description = "Redis Cache Primary Access Key"
  sensitive   = true
}

output "servicebus_endpoint" {
  value       = module.servicebus_namespace.endpoint
  description = "Service Bus Namespace Endpoint"
}

output "container_app_url" {
  value       = module.aca_app.ingress_fqdn
  description = "Container App FQDN (URL)"
}


output "key_vault_uri" {
  value       = module.key_vault.vault_uri
  description = "The URI of the Key Vault"
}

output "db_admin_username" {
  value       = var.db_admin_username
  description = "PostgreSQL Admin Username"
}

output "db_admin_password" {
  value       = var.db_admin_password
  description = "PostgreSQL Admin Password"
  sensitive   = true
}

output "storage_account_name" {
  value       = module.storage.name
  description = "The name of the Storage Account"
}

output "blob_container_name" {
  value       = "prod-mydesignation-bucket"
  description = "The name of the Blob Container"
}
