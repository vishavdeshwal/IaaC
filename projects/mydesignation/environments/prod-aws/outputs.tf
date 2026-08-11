output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "The connection endpoint for the RDS PostgreSQL database"
  value       = module.rds.endpoint
}

output "redis_primary_endpoint" {
  description = "The primary connection endpoint for the ElastiCache Redis cluster"
  value       = module.elasticache.redis_primary_endpoint
}

output "sqs_main_queue_url" {
  description = "The URL of the main SQS worker queue"
  value       = module.sqs_main.queue_url
}

output "sqs_dlq_queue_url" {
  description = "The URL of the Dead Letter Queue (DLQ)"
  value       = module.sqs_dlq.queue_url
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository for Docker images"
  value       = module.ecr.repository_url
}

output "bastion_public_ip" {
  description = "The public IP of the Bastion Host (Note: connected via SSM, no SSH keys needed)"
  value       = module.bastion.public_ip
}

output "bastion_public_ip_eip" {
  value       = aws_eip.bastion.public_ip
  description = "The Elastic IP address of the Bastion Host"
}

output "alb_logs_bucket_name" {
  description = "The S3 bucket name for ALB access logs"
  value       = aws_s3_bucket.alb_logs.id
}

