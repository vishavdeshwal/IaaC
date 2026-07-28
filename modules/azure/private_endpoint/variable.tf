variable "name" {
  type        = string
  description = "Name of the Private Endpoint."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet where the private endpoint will be created."
}

variable "private_service_connection" {
  type = object({
    name                           = string
    private_connection_resource_id = string
    subresource_names              = list(string)
    is_manual_connection           = optional(bool, false)
  })
  description = "Private service connection block."
}

variable "private_dns_zone_group" {
  type = object({
    name                 = string
    private_dns_zone_ids = list(string)
  })
  default     = null
  description = "Private DNS zone group block."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for the private endpoint."
}
