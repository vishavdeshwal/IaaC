variable "name" {
    type        = string
    description = "Base name for the SQS queue"
}

variable "fifo_queue" {
    type        = bool
    default     = false
    description = "Whether this is a FIFO queue. If true, '.fifo' suffix is automatically appended."
}

variable "visibility_timeout_seconds" {
    type        = number
    default     = 30
    description = "Visibility timeout for messages in seconds"
}

variable "message_retention_seconds" {
    type        = number
    default     = 345600 # 4 days
    description = "Number of seconds to retain a message (60 to 1209600)"
}

variable "delay_seconds" {
    type        = number
    default     = 0
    description = "Time in seconds that delivery of all messages in the queue is delayed"
}

variable "max_message_size" {
    type        = number
    default     = 262144 # 256KB
    description = "Limit of how many bytes a message can contain"
}

variable "receive_wait_time_seconds" {
    type        = number
    default     = 0
    description = "Time for which a ReceiveMessage call waits for a message to arrive (long polling)"
}

variable "content_based_deduplication" {
    type        = bool
    default     = false
    description = "Enables content-based deduplication for FIFO queues"
}

# Dead Letter Queue
variable "dlq_arn" {
    type        = string
    default     = null
    description = "ARN of the Dead Letter Queue. If null, no DLQ is configured."
}

variable "max_receive_count" {
    type        = number
    default     = 5
    description = "Number of times a message is received before being sent to the DLQ"
}

variable "environment" {
    type = string
}

variable "project" {
    type = string
}

variable "name_override" {
    type    = string
    default = null
}

variable "policy" {
    type    = string
    default = null
}


