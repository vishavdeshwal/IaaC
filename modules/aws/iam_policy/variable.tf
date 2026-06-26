variable "name" {
  type        = string
  description = "The name of the policy"
}

variable "policy" {
  type        = string
  description = "The JSON policy document"
}

variable "is_inline" {
  type        = bool
  default     = false
  description = "If true, creates an inline role policy (aws_iam_role_policy). If false, creates a customer managed policy (aws_iam_policy)."
}

variable "role_name" {
  type        = string
  default     = null
  description = "The name/ID of the IAM role to associate the policy with. Required for inline policies, optional for managed policies."
}

variable "description" {
  type        = string
  default     = null
  description = "Description of the managed policy"
}

variable "environment" {
  type        = string
  description = "Environment name tag"
}

variable "project" {
  type        = string
  description = "Project name tag"
}

variable "user_name" {
  type        = string
  default     = null
  description = "The name of the IAM user to associate the policy with."
}

