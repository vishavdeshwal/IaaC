output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "The public DNS name of the Application Load Balancer"
}

output "aurora_cluster_endpoint" {
  value       = module.aurora.cluster_endpoint
  description = "Writer endpoint of the Aurora cluster"
}

output "redis_primary_endpoint" {
  value       = module.redis.redis_primary_endpoint
  description = "Primary connection endpoint for the Redis cache"
}

output "sqs_queue_url" {
  value       = module.sqs.queue_url
  description = "URL of the application SQS queue"
}

output "sqs_dlq_url" {
  value       = module.sqs_dlq.queue_url
  description = "URL of the application SQS Dead Letter Queue"
}

output "ecr_repository_url" {
  value       = module.ecr.repository_url
  description = "The URL of the ECR repository"
}

output "ecs_cluster_name" {
  value       = module.ecs_cluster.cluster_name
  description = "The name of the ECS Cluster"
}

output "sqs_delay_queue_url" {
  value       = module.sqs_delay.queue_url
  description = "URL of the delay SQS queue"
}

output "sqs_delay_queue_arn" {
  value       = module.sqs_delay.queue_arn
  description = "ARN of the delay SQS queue"
}

output "webhook_role_arn" {
  value       = module.webhook_role.role_arn
  description = "ARN of the webhook service task IAM role"
}

output "ingest_role_arn" {
  value       = module.ingest_role.role_arn
  description = "ARN of the ingest service task IAM role"
}

output "flush_role_arn" {
  value       = module.flush_role.role_arn
  description = "ARN of the flush/migrate service task IAM role"
}

output "ecs_execution_role_arn" {
  value       = module.ecs_execution_role.role_arn
  description = "ARN of the ECS Fargate execution IAM role"
}

output "bastion_public_ip" {
  value       = module.bastion_host.public_ip
  description = "Public IP of the EC2 bastion instance"
}

output "bastion_instance_id" {
  value       = module.bastion_host.instance_id
  description = "Instance ID of the EC2 bastion instance"
}


