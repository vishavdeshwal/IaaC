variable "name" {
  type        = string
  description = "Name of the Redis Cache."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
}

variable "sku_name" {
  type        = string
  default     = "Balanced_B5"
  description = "The SKU of Azure Managed Redis to use (e.g. Balanced_B5, MemoryOptimized_M10)."
}

variable "public_network_access_enabled" {
  type        = bool
  default     = false
  description = "Whether or not public network access is allowed for this Redis Cache."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for the Redis Cache."
}
