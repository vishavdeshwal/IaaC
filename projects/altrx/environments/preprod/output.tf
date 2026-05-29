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
