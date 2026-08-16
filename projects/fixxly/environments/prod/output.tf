output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the Production VPC"
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

output "rds_backend_postgres_endpoint" {
  value       = module.rds_backend_postgres.endpoint
  description = "Connection endpoint for Dedicated Backend RDS PostgreSQL instance (db.m5.xlarge)"
}

output "redis_primary_endpoint" {
  value       = module.elasticache_redis.redis_primary_endpoint
  description = "Primary endpoint address for ElastiCache Redis cluster"
}

output "ecs_cluster_name" {
  value       = module.ecs_cluster.cluster_name
  description = "Name of the Production ECS Cluster"
}

# --- ECR Repository Outputs (18 Repositories) ---

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

output "ecr_frontend_repository_url" {
  value       = module.ecr_frontend.repository_url
  description = "ECR Repository URL for Web Frontend image"
}

output "ecr_consumer_bff_repository_url" {
  value       = module.ecr_consumer_bff.repository_url
}

output "ecr_auth_service_repository_url" {
  value       = module.ecr_auth_service.repository_url
}

output "ecr_product_service_repository_url" {
  value       = module.ecr_product_service.repository_url
}

output "ecr_order_service_repository_url" {
  value       = module.ecr_order_service.repository_url
}

output "ecr_cart_service_repository_url" {
  value       = module.ecr_cart_service.repository_url
}

output "ecr_inventory_service_repository_url" {
  value       = module.ecr_inventory_service.repository_url
}

output "ecr_cms_bridge_repository_url" {
  value       = module.ecr_cms_bridge.repository_url
}

output "ecr_coupon_service_repository_url" {
  value       = module.ecr_coupon_service.repository_url
}

output "ecr_notification_service_repository_url" {
  value       = module.ecr_notification_service.repository_url
}

output "ecr_payment_service_repository_url" {
  value       = module.ecr_payment_service.repository_url
}

output "ecr_erp_sync_service_repository_url" {
  value       = module.ecr_erp_sync_service.repository_url
}

output "ecr_wallet_service_repository_url" {
  value       = module.ecr_wallet_service.repository_url
}

output "ecr_assets_service_repository_url" {
  value       = module.ecr_assets_service.repository_url
}

output "ecr_serviceability_service_repository_url" {
  value       = module.ecr_serviceability_service.repository_url
}

# --- Service Discovery Output ---

output "service_discovery_namespace_name" {
  value       = aws_service_discovery_private_dns_namespace.internal.name
  description = "Cloud Map Private DNS Namespace Name"
}

output "msk_cluster_arn" {
  value       = module.msk.cluster_arn
  description = "ARN of the Amazon MSK Managed Kafka Cluster"
}

output "msk_bootstrap_brokers_plaintext" {
  value       = module.msk.bootstrap_brokers_plaintext
  description = "Connection string for Amazon MSK Managed Kafka bootstrap brokers"
}

# --- Secrets & IAM Outputs ---

output "backend_secrets_arn" {
  value       = module.backend_secrets.secret_arn
  description = "ARN of the backend Secrets Manager secret"
}

output "saleor_secrets_arn" {
  value       = module.saleor_secrets.secret_arn
  description = "ARN of the Saleor Secrets Manager secret"
}

output "strapi_secrets_arn" {
  value       = module.strapi_secrets.secret_arn
  description = "ARN of the Strapi Secrets Manager secret"
}

output "s3_media_bucket_name" {
  value       = module.s3_media.bucket_name
  description = "Name of the Public S3 Media Bucket for Saleor and Strapi"
}

output "s3_media_bucket_domain" {
  value       = module.s3_media.bucket_regional_domain_name
  description = "Regional domain name of the Public S3 Media Bucket"
}

output "saleor_execution_role_arn" {
  value       = module.ecs_saleor_execution_role.role_arn
  description = "Execution role ARN for Saleor ECS services"
}

output "saleor_task_role_arn" {
  value       = module.ecs_saleor_task_role.role_arn
  description = "Task role ARN for Saleor ECS services"
}

output "strapi_execution_role_arn" {
  value       = module.ecs_strapi_execution_role.role_arn
  description = "Execution role ARN for Strapi ECS service"
}

output "strapi_task_role_arn" {
  value       = module.ecs_strapi_task_role.role_arn
  description = "Task role ARN for Strapi ECS service"
}

output "backend_execution_role_arn" {
  value       = module.ecs_backend_execution_role.role_arn
  description = "Execution role ARN for Backend ECS microservices"
}

output "backend_task_role_arn" {
  value       = module.ecs_backend_task_role.role_arn
  description = "Task role ARN for Backend ECS microservices"
}

output "frontend_execution_role_arn" {
  value       = module.ecs_frontend_execution_role.role_arn
  description = "Execution role ARN for Web Frontend ECS service"
}

output "frontend_task_role_arn" {
  value       = module.ecs_frontend_task_role.role_arn
  description = "Task role ARN for Web Frontend ECS service"
}
