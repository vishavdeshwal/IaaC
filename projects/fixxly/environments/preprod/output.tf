output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the Pre-Prod VPC"
}

output "public_subnet_ids" {
  value       = module.subnets.public_subnet_ids
  description = "Map of public subnet IDs"
}

output "private_subnet_ids" {
  value       = module.subnets.private_subnet_ids
  description = "Map of private subnet IDs"
}

output "bastion_public_ip" {
  value       = module.bastion_eip.public_ip
  description = "Elastic IP address allocated and associated with the Bastion Host"
}

output "erp_private_ip" {
  value       = module.erp_server.private_ip
  description = "Private IP address of the ERP EC2 Server"
}

output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "DNS Name of the Application Load Balancer"
}

output "rds_mariadb_endpoint" {
  value       = module.rds_mariadb.endpoint
  description = "Connection endpoint for RDS MariaDB instance"
}

output "rds_postgres_endpoint" {
  value       = module.rds_postgres.endpoint
  description = "Connection endpoint for RDS PostgreSQL instance (for Saleor & Strapi)"
}

output "redis_primary_endpoint" {
  value       = module.elasticache_redis.redis_primary_endpoint
  description = "Primary endpoint address for ElastiCache Redis cluster"
}

output "ecs_cluster_name" {
  value       = module.ecs_cluster.cluster_name
  description = "Name of the ECS Cluster hosting Strapi and Saleor"
}

output "ecr_saleor_repository_url" {
  value       = module.ecr_saleor.repository_url
  description = "ECR Repository URL for Saleor image"
}

output "ecr_saleor_dashboard_repository_url" {
  value       = module.ecr_saleor_dashboard.repository_url
  description = "ECR Repository URL for Saleor Dashboard image"
}

output "ecr_strapi_repository_url" {
  value       = module.ecr_strapi.repository_url
  description = "ECR Repository URL for Strapi image"
}

output "backend_secrets_arn" {
  value       = module.backend_secrets.secret_arn
  description = "ARN of the backend Secrets Manager secret"
}

output "saleor_secrets_arn" {
  value       = module.saleor_secrets.secret_arn
  description = "ARN of the Saleor Secrets Manager secret"
}

output "postgres_db_secrets_arn" {
  value       = module.postgres_db_secrets.secret_arn
  description = "ARN of the PostgreSQL database Secrets Manager secret"
}

output "s3_media_bucket_name" {
  value       = module.s3_media.bucket_name
  description = "Name of the Public S3 Media Bucket for Saleor and Strapi"
}

output "s3_media_bucket_domain" {
  value       = module.s3_media.bucket_regional_domain_name
  description = "Regional domain name of the Public S3 Media Bucket"
}
