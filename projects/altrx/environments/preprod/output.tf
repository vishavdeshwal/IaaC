output "alb_dns_name" {
  value       = module.preprod_alb.alb_dns_name
  description = "The public DNS name of the Application Load Balancer"
}

output "ecs_cluster_name" {
  value       = module.ecs_cluster.cluster_name
  description = "The name of the shared ECS Cluster"
}

output "redis_primary_endpoint" {
  value       = module.preprod_redis.redis_primary_endpoint
  description = "Primary connection endpoint for the Redis cache"
}

output "sqs_payment_events_queue_url" {
  value       = module.preprod_payment_events.queue_url
  description = "URL of the payment-events SQS Queue"
}

output "sqs_payment_events_dlq_url" {
  value       = module.preprod_payment_events_dlq.queue_url
  description = "URL of the payment-events Dead Letter Queue"
}

output "sqs_reconciler_trigger_queue_url" {
  value       = module.reconciler_trigger.queue_url
  description = "URL of the reconciler-trigger SQS Queue"
}

output "lambda_reconciler_arn" {
  value       = module.lambda_reconciler.function_arn
  description = "The ARN of the reconciler Lambda function"
}

output "dynamodb_payment_events_log_id" {
  value       = module.dynamodb_payment_events_log.table_id
  description = "Name of the payment-events-log DynamoDB table"
}

output "dynamodb_stripe_customers_id" {
  value       = module.dynamodb_stripe_customers.table_id
  description = "Name of the stripe-customers DynamoDB table"
}

output "dynamodb_processed_events_id" {
  value       = module.dynamodb_processed_events.table_id
  description = "Name of the processed-events DynamoDB table"
}

output "dynamodb_checkout_submissions_id" {
  value       = module.dynamodb_checkout_submissions.table_id
  description = "Name of the checkout-submissions DynamoDB table"
}

output "dynamodb_weight_logs_id" {
  value       = module.dynamodb_weight_logs.table_id
  description = "Name of the weight-logs DynamoDB table"
}

output "sqs_reconciler_trigger_dlq_url" {
  value       = module.reconciler_trigger_dlq.queue_url
  description = "URL of the reconciler-trigger SQS Dead Letter Queue"
}

output "ecr_preprod_backend_repository_url" {
  value       = module.ecr_preprod_backend.repository_url
  description = "Repository URL for the preprod backend container image"
}

output "ecr_preprod_worker_repository_url" {
  value       = module.ecr_preprod_worker.repository_url
  description = "Repository URL for the preprod worker container image"
}

output "ecr_reconciler_repository_url" {
  value       = module.ecr_reconciler.repository_url
  description = "Repository URL for the reconciler container image"
}

output "s3_uploads_bucket_name" {
  value       = aws_s3_bucket.uploads.id
  description = "Name of the preprod S3 uploads bucket"
}

output "s3_uploads_bucket_arn" {
  value       = aws_s3_bucket.uploads.arn
  description = "ARN of the preprod S3 uploads bucket"
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the preprod VPC"
}

output "private_subnet_ids" {
  value       = module.subnets.private_subnet_ids
  description = "Mapping of private subnet keys to IDs"
}

output "public_subnet_ids" {
  value       = module.subnets.public_subnet_ids
  description = "Mapping of public subnet keys to IDs"
}

output "ecs_task_execution_role_arn" {
  value       = module.iam_ecs_task_execution_role.role_arn
  description = "ARN of the ECS task execution role for preprod"
}

output "ssm_role_arn" {
  value       = module.iam_altrx_ssm_role.role_arn
  description = "ARN of the SSM role for preprod"
}

output "security_group_preprod_alb_id" {
  value       = module.preprod_alb_sg.security_group_id
  description = "Security Group ID for the preprod ALB"
}

output "security_group_preprod_be_id" {
  value       = module.preprod_be_sg.security_group_id
  description = "Security Group ID for the preprod Backend service"
}

output "security_group_preprod_worker_id" {
  value       = module.preprod_worker_sg.security_group_id
  description = "Security Group ID for the preprod Worker service"
}

output "security_group_preprod_redis_id" {
  value       = module.preprod_redis_sg.security_group_id
  description = "Security Group ID for the preprod Redis cluster"
}


