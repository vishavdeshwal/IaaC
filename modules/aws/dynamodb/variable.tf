variable "name" {
  type        = string
  description = "The name of the DynamoDB table"
}

variable "billing_mode" {
  type        = string
  default     = "PAY_PER_REQUEST"
  description = "Controls how you are charged for read and write throughput"
}

variable "hash_key" {
  type        = string
  description = "The attribute to use as the partition key"
}

variable "range_key" {
  type        = string
  default     = null
  description = "The attribute to use as the sort key"
}

variable "deletion_protection_enabled" {
  type        = bool
  default     = false
  description = "Enables deletion protection for the table"
}

variable "table_class" {
  type        = string
  default     = "STANDARD"
  description = "The storage class of the table"
}

variable "stream_enabled" {
  type        = bool
  default     = false
  description = "Indicates whether Streams are enabled"
}

variable "stream_view_type" {
  type        = string
  default     = null
  description = "When stream_enabled is true, defines the information written to the stream"
}

variable "attributes" {
  type = list(object({
    name = string
    type = string
  }))
  description = "List of nested attribute definitions for key schema"
}

variable "global_secondary_indexes" {
  type        = any
  default     = []
  description = "List of global secondary indexes configuration maps"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. staging, prod)"
}

variable "project" {
  type        = string
  description = "Project name tag value"
}
