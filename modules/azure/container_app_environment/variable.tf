variable "name" {
  type        = string
  description = "Name of the Container App Environment."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
}

variable "infrastructure_subnet_id" {
  type        = string
  default     = null
  description = "ID of the delegated subnet."
}

variable "internal_load_balancer_enabled" {
  type        = bool
  default     = false
  description = "Whether the Environment is internal or external."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for the environment."
}
