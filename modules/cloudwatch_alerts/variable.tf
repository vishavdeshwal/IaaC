variable "environment" {
  type        = string
  description = "The target environment (e.g. prod, preprod, staging)"
}

variable "project" {
  type        = string
  description = "The project namespace (e.g. ALTRX)"
  default     = "ALTRX"
}

variable "log_group_name" {
  type        = string
  description = "The name of the CloudWatch Log Group to attach metric filters to"
}

variable "sns_topic_arn" {
  type        = string
  description = "The ARN of the pre-provisioned SNS topic to send alerts to"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to created resources"
}
