output "id" {
  value       = azurerm_role_assignment.this.id
  description = "Role assignment ID."
}

output "principal_id" {
  value       = azurerm_role_assignment.this.principal_id
  description = "Principal the role was assigned to."
}
