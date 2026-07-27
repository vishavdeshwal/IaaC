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

variable "security_rules" {
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  default     = []
  description = "List of NSG security rules."
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
