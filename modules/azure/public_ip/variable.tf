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

variable "allocation_method" {
  type        = string
  default     = "Static"
  description = "Static or Dynamic. Standard SKU requires Static."
}

variable "sku" {
  type        = string
  default     = "Standard"
  description = "Basic or Standard."
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
