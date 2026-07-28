variable "name" {
  type        = string
  description = "Name of the PostgreSQL Flexible Server."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "pg_version" {
  type        = string
  default     = "16"
  description = "PostgreSQL version."
}

variable "delegated_subnet_id" {
  type        = string
  description = "ID of the delegated subnet."
}

variable "private_dns_zone_id" {
  type        = string
  description = "ID of the private DNS zone."
}

variable "administrator_login" {
  type        = string
  description = "Administrator login name."
}

variable "administrator_password" {
  type        = string
  sensitive   = true
  description = "Administrator password."
}

variable "storage_mb" {
  type        = number
  default     = 32768
  description = "Max storage allowed for the server in MB."
}

variable "sku_name" {
  type        = string
  default     = "B_Standard_B1ms"
  description = "SKU Name for the PostgreSQL Flexible Server."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for the resource."
}
