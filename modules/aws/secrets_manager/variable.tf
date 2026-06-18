variable "secret_name" {
  type        = string
  description = "The name of the Secrets Manager secret"
}

variable "secret_string" {
  type        = string
  default     = "dummy-value"
  description = "The initial value of the secret"
}

variable "recovery_window_in_days" {
  type        = number
  default     = 0
  description = "Number of days that AWS Secrets Manager waits before deleting the secret (0 to 30)"
}

variable "environment" {
  type        = string
  description = "Environment tag"
}

variable "project" {
  type        = string
  description = "Project tag"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to the secret"
}
