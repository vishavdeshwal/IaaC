variable "name" {
  type        = string
  description = "Name of the subnet."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
}

variable "virtual_network_name" {
  type        = string
  description = "Name of the virtual network."
}

variable "address_prefixes" {
  type        = list(string)
  description = "Address prefixes for the subnet."
}

variable "service_endpoints" {
  type        = list(string)
  default     = []
  description = "Service endpoints to associate with the subnet."
}

variable "delegation" {
  type = object({
    name                       = string
    service_delegation_name    = string
    service_delegation_actions = list(string)
  })
  default     = null
  description = "Delegation block for the subnet."
}
