variable "cluster_name" {
  type        = string
  description = "The name of the ECS cluster"
}

variable "enable_container_insights" {
  type        = bool
  default     = false
  description = "Enables CloudWatch Container Insights"
}

variable "environment" {
  type        = string
  description = "Environment name tag"
}

variable "project" {
  type        = string
  description = "Project name tag"
}
