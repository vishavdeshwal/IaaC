variable "name" {
  type        = string
  description = "The name of the CloudWatch Log Group."
}

variable "retention_in_days" {
  type        = number
  default     = 7
  description = "Specifies the number of days to retain log events in the specified log group."
}

variable "log_group_class" {
  type        = string
  default     = "STANDARD"
  description = "Specifies the log class of the log group (STANDARD or INFREQUENT_ACCESS)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign to the log group."
}
