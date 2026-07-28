variable "name" {
  type        = string
  description = "Name of the Private DNS zone."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
}

variable "virtual_network_links" {
  type        = map(string)
  default     = {}
  description = "Map of virtual network link name => virtual network ID."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for the private DNS zone."
}
