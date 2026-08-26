output "app_public_ip" {
  description = "The public Elastic IP address of the Standalone Application EC2 Instance"
  value       = aws_eip.app.public_ip
}

output "app_private_ip" {
  description = "The private IP address of the Standalone Application EC2 Instance"
  value       = module.app_server.private_ip
}

output "sqs_main_queue_url" {
  description = "The URL of the main SQS worker queue"
  value       = module.sqs_main.queue_url
}

output "sqs_dlq_queue_url" {
  description = "The URL of the Dead Letter Queue (DLQ)"
  value       = module.sqs_dlq.queue_url
}

output "app_s3_bucket_name" {
  description = "The name of the application S3 bucket for media/assets"
  value       = aws_s3_bucket.app_bucket.id
}
