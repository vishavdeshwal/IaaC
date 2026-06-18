output "queue_url" {
    value       = aws_sqs_queue.queue.url
    description = "URL of the SQS queue"
}

output "queue_arn" {
    value       = aws_sqs_queue.queue.arn
    description = "ARN of the SQS queue"
}

output "queue_name" {
    value       = aws_sqs_queue.queue.name
    description = "Name of the SQS queue"
}

output "queue_id" {
    value       = aws_sqs_queue.queue.id
    description = "ID (URL) of the SQS queue"
}
