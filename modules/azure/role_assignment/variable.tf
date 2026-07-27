variable "scope" {
  type        = string
  description = "Resource ID the role applies to (e.g. a storage account ID)."
}

variable "role_definition_name" {
  type        = string
  description = "Built-in or custom role name (e.g. 'Storage Queue Data Contributor')."
}

variable "principal_id" {
  type        = string
  description = "Object ID of the principal (managed identity / user / group / SP)."
}
