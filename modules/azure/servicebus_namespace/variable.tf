variable "name" {
  type    = string
  default = "bus"
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

variable "sku" {
  type        = string
  default     = "Basic"
  description = "Basic, Standard, or Premium."
}

variable "capacity" {
  type        = number
  default     = 1
  description = "Messaging units (Premium only). Ignored for Basic/Standard."
}

variable "authorization_rules" {
  type = map(object({
    listen = bool
    send   = bool
    manage = bool
  }))
  default     = {}
  description = "Map of namespace-level SAS policy name => rights. Note: manage must be false on Basic SKU."
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
