variable "function_arn" {
    type        = string
    description = "ARN of the Lambda function to attach the trigger to"
}

variable "function_name" {
    type        = string
    description = "Name of the Lambda function (used for CloudWatch event target)"
}

# ---- SQS Trigger ----

variable "sqs_trigger_enabled" {
    type        = bool
    default     = false
    description = "Whether to create an SQS event source mapping trigger"
}

variable "sqs_queue_arn" {
    type        = string
    default     = null
    description = "ARN of the SQS queue to use as trigger. Required if sqs_trigger_enabled = true."
}

variable "sqs_batch_size" {
    type        = number
    default     = 10
    description = "Maximum number of records per batch from SQS"
}

variable "sqs_maximum_batching_window" {
    type        = number
    default     = 0
    description = "Maximum batching window in seconds (0–300)"
}

# ---- EventBridge (CloudWatch Events) Schedule Trigger ----

variable "schedule_trigger_enabled" {
    type        = bool
    default     = false
    description = "Whether to create an EventBridge schedule trigger"
}

variable "schedule_expression" {
    type        = string
    default     = null
    description = "Schedule expression (e.g. 'rate(5 minutes)' or 'cron(0 12 * * ? *)')"
}

variable "schedule_description" {
    type        = string
    default     = "Scheduled trigger for Lambda"
    description = "Description for the EventBridge rule"
}

# ---- S3 Trigger ----

variable "s3_trigger_enabled" {
    type        = bool
    default     = false
    description = "Whether to create an S3 bucket notification trigger"
}

variable "s3_bucket_id" {
    type        = string
    default     = null
    description = "ID of the S3 bucket to trigger Lambda from"
}

variable "s3_events" {
    type        = list(string)
    default     = ["s3:ObjectCreated:*"]
    description = "List of S3 event types to trigger on"
}

variable "s3_filter_prefix" {
    type        = string
    default     = null
    description = "Optional prefix filter for S3 notifications (e.g. 'uploads/')"
}

variable "s3_filter_suffix" {
    type        = string
    default     = null
    description = "Optional suffix filter for S3 notifications (e.g. '.jpg')"
}

variable "environment" {
    type = string
}

variable "project" {
    type = string
}
