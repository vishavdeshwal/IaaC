output "alb_dns_name" {
  value       = module.prod_alb.alb_dns_name
  description = "The public DNS name of the Application Load Balancer"
}

output "ecs_cluster_name" {
  value       = module.ecs_cluster.cluster_name
  description = "The name of the shared ECS Cluster"
}

output "redis_primary_endpoint" {
  value       = module.prod_redis.redis_primary_endpoint
  description = "Primary connection endpoint for the Redis cache"
}

output "sqs_payment_events_queue_url" {
  value       = module.prod_payment_events.queue_url
  description = "URL of the payment-events SQS Queue"
}

output "sqs_payment_events_dlq_url" {
  value       = module.prod_payment_events_dlq.queue_url
  description = "URL of the payment-events Dead Letter Queue"
}

output "sqs_reconciler_trigger_queue_url" {
  value       = module.prod_reconciler_trigger.queue_url
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

output "strapie_postgres_endpoint" {
  value       = module.prod_strapie_db.endpoint
  description = "Connection endpoint for the production Strapie Postgres database"
}

output "strapie_postgres_identifier" {
  value       = module.prod_strapie_db.instance_id
  description = "Identifier of the production Strapie Postgres database"
}

output "strapie_server_role_arn" {
  value       = module.iam_altrx_ssm_role.role_arn
  description = "IAM Role ARN attached to the production Strapie Server"
}

output "strapie_uploads_bucket_name" {
  value       = aws_s3_bucket.strapie_uploads.id
  description = "Name of the production Strapie uploads S3 bucket"
}

output "strapie_uploads_bucket_arn" {
  value       = aws_s3_bucket.strapie_uploads.arn
  description = "ARN of the production Strapie uploads S3 bucket"
}

output "sqs_cv_case_events_queue_url" {
  value       = module.cv_case_events.queue_url
  description = "URL of the cv-case-events SQS Queue"
}

output "sqs_cv_case_events_dlq_url" {
  value       = module.cv_case_events_dlq.queue_url
  description = "URL of the cv-case-events Dead Letter Queue"
}

output "sqs_cv_case_events_queue_arn" {
  value       = module.cv_case_events.queue_arn
  description = "ARN of the cv-case-events SQS Queue"
}

output "sqs_cv_case_events_dlq_arn" {
  value       = module.cv_case_events_dlq.queue_arn
  description = "ARN of the cv-case-events Dead Letter Queue"
}

output "ecr_prod_cv_case_events_url" {
  value       = module.ecr_prod_cv_case_events.repository_url
  description = "URL of the cv-case-events ECR Repository"
}



