variable "cluster_name" {
  type        = string
  description = "The name of the ECS cluster"
}

variable "enable_container_insights" {
  type        = bool
  default     = false
  description = "Enables CloudWatch Container Insights. Maps to 'enabled'/'disabled'. Ignored when container_insights_value is set."
}

variable "container_insights_value" {
  type        = string
  default     = null
  description = "Explicit containerInsights tier: 'enhanced', 'enabled' or 'disabled'. Overrides enable_container_insights when set. Needed because the bool cannot express the 'enhanced' tier."

  validation {
    condition     = var.container_insights_value == null || contains(["enhanced", "enabled", "disabled"], coalesce(var.container_insights_value, "enabled"))
    error_message = "container_insights_value must be one of: enhanced, enabled, disabled."
  }
}

variable "environment" {
  type        = string
  description = "Environment name tag"
}

variable "project" {
  type        = string
  description = "Project name tag"
}
