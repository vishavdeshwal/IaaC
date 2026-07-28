variable "name" {
  type        = string
  description = "Specifies the name of the Container Registry. Only Alphanumeric characters allowed."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which to create the Container Registry."
}

variable "location" {
  type        = string
  description = "Specifies the supported Azure location where the resource exists."
}

variable "sku" {
  type        = string
  default     = "Basic"
  description = "The SKU name of the container registry. Possible values are Basic, Standard and Premium."
}

variable "admin_enabled" {
  type        = bool
  default     = true
  description = "Specifies whether the admin user is enabled."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A mapping of tags to assign to the resource."
}
