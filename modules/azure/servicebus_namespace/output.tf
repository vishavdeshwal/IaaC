output "id" {
  value       = azurerm_servicebus_namespace.this.id
  description = "Service Bus namespace ID."
}

output "name" {
  value       = azurerm_servicebus_namespace.this.name
  description = "Service Bus namespace name."
}

output "endpoint" {
  value       = azurerm_servicebus_namespace.this.endpoint
  description = "Service Bus namespace endpoint URL."
}

output "authorization_rule_connection_strings" {
  value       = { for k, r in azurerm_servicebus_namespace_authorization_rule.this : k => r.primary_connection_string }
  description = "Map of namespace SAS policy name => primary connection string."
  sensitive   = true
}
