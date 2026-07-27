variable "name" {
  type    = string
  default = "vnet"
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

variable "address_space" {
  type        = list(string)
  description = "VNet CIDR block(s)."
}

variable "subnets" {
  type = map(object({
    address_prefixes                = list(string)
    default_outbound_access_enabled = optional(bool, true)
  }))
  default     = {}
  description = "Map of subnet name => { address_prefixes, default_outbound_access_enabled }."
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
