locals {
  # FIFO queues require the .fifo suffix
  queue_name = var.name_override != null ? var.name_override : (var.fifo_queue ? "${var.environment}-${var.project}-${var.name}.fifo" : "${var.environment}-${var.project}-${var.name}")

  redrive_policy = var.dlq_arn != null ? jsonencode({
    deadLetterTargetArn = var.dlq_arn
    maxReceiveCount     = var.max_receive_count
  }) : null
}

resource "aws_sqs_queue" "queue" {
  name                        = local.queue_name
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  delay_seconds              = var.delay_seconds
  max_message_size           = var.max_message_size
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  redrive_policy = local.redrive_policy
  policy         = var.policy

  tags = {
    Name        = local.queue_name
    Environment = var.environment
    Project     = var.project
  }
}
