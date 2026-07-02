variable "name" {
  type        = string
  description = "Name for the SNS topic"
}

variable "name_override" {
  type        = string
  default     = null
  description = "Explicit name override"
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}
