variable "name" {
  type        = string
  description = "The name of the IAM role"
}

variable "assume_role_policy" {
  type        = string
  description = "The trust policy document in JSON format"
}

variable "path" {
  type        = string
  default     = "/"
  description = "The path to the role"
}

variable "description" {
  type        = string
  default     = null
  description = "The description of the role"
}

variable "policy_arns" {
  type        = list(string)
  default     = []
  description = "List of policy ARNs to attach to this role"
}

variable "environment" {
  type        = string
  description = "Environment name tag"
}

variable "project" {
  type        = string
  description = "Project name tag"
}
