variable "subscription_id" {
  type        = string
  description = "Azure subscription ID (MYDPremium)."
}

variable "location" {
  type        = string
  default     = "southindia"
  description = "Azure region."
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "staging_application_ssh_public_key" {
  type        = string
  description = "Public key for the staging-application VM + its stored SSH key resource."
}

variable "testing1_ssh_public_key" {
  type        = string
  description = "Public key for the testing1_key stored SSH key resource."
}

variable "vm_identity_principal_id" {
  type        = string
  description = "Object ID of the VM's system-assigned managed identity (target of the role assignment)."
}

variable "vnet_app_subnets" {
  type = map(object({
    address_prefixes                = list(string)
    default_outbound_access_enabled = optional(bool)
  }))
  description = "Subnets configuration for the application VNet."
}

variable "vnet_production_subnets" {
  type = map(object({
    address_prefixes                = list(string)
    default_outbound_access_enabled = optional(bool)
  }))
  description = "Subnets configuration for the production VNet."
}
