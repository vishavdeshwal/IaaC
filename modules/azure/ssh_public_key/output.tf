output "id" {
  value       = azurerm_ssh_public_key.this.id
  description = "SSH public key resource ID."
}

output "name" {
  value       = azurerm_ssh_public_key.this.name
  description = "SSH public key resource name."
}
