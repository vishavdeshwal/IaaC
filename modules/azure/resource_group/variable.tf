variable "name" {
  type        = string
  default     = "rg"
  description = "Base name. Final name is <environment>-<project>-<name> unless name_override is set."
}

variable "name_override" {
  type        = string
  default     = null
  description = "Explicit resource name, bypassing the naming convention. Used for imported resources."
}

variable "location" {
  type        = string
  description = "Azure region (e.g. southindia)."
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags, merged over the standard Name/Environment/Project tags."
}
