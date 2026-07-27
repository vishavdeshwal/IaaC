variable "name" {
  type    = string
  default = "queue"
}

variable "name_override" {
  type    = string
  default = null
}

variable "namespace_id" {
  type        = string
  description = "Parent Service Bus namespace ID."
}

variable "max_delivery_count" {
  type        = number
  default     = 10
  description = "Deliveries attempted before a message is dead-lettered."
}

variable "dead_lettering_on_message_expiration" {
  type    = bool
  default = true
}

variable "lock_duration" {
  type        = string
  default     = "PT1M"
  description = "ISO-8601 lock duration (e.g. PT1M = 1 minute)."
}

variable "max_size_in_megabytes" {
  type    = number
  default = 1024
}

variable "default_message_ttl" {
  type        = string
  default     = "P14D"
  description = "ISO-8601 default message time-to-live (e.g. P14D = 14 days)."
}

variable "authorization_rules" {
  type = map(object({
    listen = bool
    send   = bool
    manage = bool
  }))
  default     = {}
  description = "Map of queue-level SAS policy name => rights."
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}
