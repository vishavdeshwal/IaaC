variable "name" {
  type    = string
  default = "app"
}

variable "name_override" {
  type    = string
  default = null
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "size" {
  type        = string
  default     = "Standard_B2ms"
  description = "VM SKU size."
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "admin_ssh_public_key" {
  type        = string
  description = "OpenSSH public key baked into the VM for the admin user."
}

variable "network_interface_ids" {
  type        = list(string)
  description = "One or more NIC IDs to attach (first is primary)."
}

variable "os_disk_caching" {
  type    = string
  default = "ReadWrite"
}

variable "os_disk_storage_account_type" {
  type    = string
  default = "Premium_LRS"
}

variable "image_publisher" {
  type    = string
  default = "canonical"
}

variable "image_offer" {
  type    = string
  default = "ubuntu-24_04-lts"
}

variable "image_sku" {
  type    = string
  default = "server"
}

variable "image_version" {
  type    = string
  default = "latest"
}

variable "identity_type" {
  type        = string
  default     = "SystemAssigned"
  description = "Managed identity type, or null to disable."
}

variable "secure_boot_enabled" {
  type        = bool
  default     = null
  description = "Enable Secure Boot (Trusted Launch). Leave null for standard VMs."
}

variable "vtpm_enabled" {
  type        = bool
  default     = null
  description = "Enable vTPM (Trusted Launch). Leave null for standard VMs."
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
