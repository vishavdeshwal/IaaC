output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.subnets.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.subnets.private_subnet_ids
}

output "nat_gateway_public_ip" {
  description = "Public IP of NAT Gateway"
  value       = module.nat_eip.public_ip
}

output "s3_gateway_endpoint_id" {
  description = "VPC S3 Gateway Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}

output "bastion_public_ip" {
  description = "Elastic IP of Prod Bastion Host"
  value       = module.bastion_eip.public_ip
}

output "erp_server_private_ip" {
  description = "Private IP of ERP EC2 Instance"
  value       = module.erp_server.private_ip
}

output "alb_dns_name" {
  description = "DNS Name of Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Canonical Hosted Zone ID of Application Load Balancer"
  value       = module.alb.alb_zone_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS Cluster"
  value       = module.ecs_cluster.cluster_name
}

output "ecr_repositories" {
  description = "ECR Repository URLs"
  value = {
    frontend         = module.ecr_frontend.repository_url
    backend          = module.ecr_backend.repository_url
    saleor_api       = module.ecr_saleor_api.repository_url
    saleor_dashboard = module.ecr_saleor_dashboard.repository_url
    strapi           = module.ecr_strapi.repository_url
  }
}

output "secrets_manager_arns" {
  description = "ARNs of AWS Secrets Manager secrets"
  value = {
    backend = module.backend_secrets.secret_arn
    saleor  = module.saleor_secrets.secret_arn
    strapi  = module.strapi_secrets.secret_arn
  }
}

output "rds_mariadb_endpoint" {
  description = "Endpoint of ERP MariaDB RDS Instance"
  value       = module.rds_mariadb.endpoint
}

output "rds_postgres_saleor_strapi_endpoint" {
  description = "Endpoint of Saleor & Strapi PostgreSQL RDS Instance"
  value       = module.rds_postgres.endpoint
}

output "rds_backend_postgres_endpoint" {
  description = "Endpoint of Backend PostgreSQL RDS Instance"
  value       = module.rds_backend_postgres.endpoint
}

output "redis_backend_endpoint" {
  description = "Primary endpoint for Backend ElastiCache Redis"
  value       = module.elasticache_redis.redis_primary_endpoint
}

output "redis_erp_endpoint" {
  description = "Primary endpoint for ERP ElastiCache Redis"
  value       = module.elasticache_erp_redis.redis_primary_endpoint
}

output "s3_media_bucket_name" {
  description = "Name of the S3 media and assets bucket"
  value       = module.s3_media.bucket_name
}

output "cloudfront_distribution_domain" {
  description = "Domain name of the CloudFront distribution"
  value       = module.cdn.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.cdn.cloudfront_distribution_id
}

output "sqs_media_queue_url" {
  description = "URL of SQS Media Events queue"
  value       = module.sqs_media_events.queue_url
}

output "guardduty_detector_id" {
  description = "GuardDuty Detector ID"
  value       = aws_guardduty_detector.primary.id
}
