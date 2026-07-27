output "id" {
  value       = azurerm_servicebus_queue.this.id
  description = "Service Bus queue ID."
}

output "name" {
  value       = azurerm_servicebus_queue.this.name
  description = "Service Bus queue name."
}

output "authorization_rule_connection_strings" {
  value       = { for k, r in azurerm_servicebus_queue_authorization_rule.this : k => r.primary_connection_string }
  description = "Map of queue SAS policy name => primary connection string (includes EntityPath)."
  sensitive   = true
}
