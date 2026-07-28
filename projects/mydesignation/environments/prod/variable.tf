variable "subscription_id" {
  type        = string
  description = "Azure subscription ID (MYDPremium)."
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "bastion_ssh_public_key" {
  type        = string
  description = "Public key for the Bastion Linux VM."
}

variable "db_admin_username" {
  type    = string
  default = "postgresadmin"
}

variable "db_admin_password" {
  type      = string
  sensitive = true
}

variable "vnet_address_space" {
  type = list(string)
}

variable "vnet_subnets" {
  type = map(object({
    address_prefixes                = list(string)
    default_outbound_access_enabled = optional(bool)
  }))
  description = "Non-delegated subnets (Bastion, Cache)."
}

variable "aca_subnet_prefixes" {
  type        = list(string)
  description = "CIDR prefixes for ACA subnet."
}

variable "db_subnet_prefixes" {
  type        = list(string)
  description = "CIDR prefixes for DB subnet."
}
