variable "name" {
  type        = string
  description = "Name of the Container App."
}

variable "container_app_environment_id" {
  type        = string
  description = "ID of the Container App Environment."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
}

variable "revision_mode" {
  type        = string
  default     = "Single"
  description = "Revision mode (Single or Multiple)."
}

variable "identity_type" {
  type        = string
  default     = "SystemAssigned"
  description = "Type of Managed Identity."
}

variable "min_replicas" {
  type        = number
  default     = 0
}

variable "max_replicas" {
  type        = number
  default     = 10
}

variable "containers" {
  type = list(object({
    name   = string
    image  = string
    cpu    = number
    memory = string
  }))
  description = "List of containers to run."
}

variable "ingress" {
  type = object({
    allow_insecure_connections = optional(bool, false)
    external_enabled           = optional(bool, true)
    target_port                = number
    traffic_weight = optional(object({
      percentage      = number
      latest_revision = bool
    }), null)
  })
  default     = null
  description = "Ingress configuration."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for the container app."
}
