output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "The public DNS name of the Application Load Balancer"
}

output "postgres_endpoint" {
  value       = module.rds_postgres.endpoint
  description = "Endpoint of the RDS PostgreSQL instance"
}

output "redis_primary_endpoint" {
  value       = module.redis.redis_primary_endpoint
  description = "Primary connection endpoint for the Redis cache"
}

output "ecr_frontend_url" {
  value       = module.ecr_frontend.repository_url
  description = "The URL of the ECR repository for frontend"
}

output "ecr_backend_url" {
  value       = module.ecr_backend.repository_url
  description = "The URL of the ECR repository for backend"
}

output "ecr_saleor_url" {
  value       = module.ecr_saleor.repository_url
  description = "The URL of the ECR repository for saleor"
}

output "ecs_cluster_name" {
  value       = module.ecs_cluster.cluster_name
  description = "The name of the ECS Cluster"
}

output "bastion_public_ip" {
  value       = module.bastion_eip.public_ip
  description = "Public IP of the EC2 bastion instance (Elastic IP)"
}

output "strapi_private_ip" {
  value       = module.strapi_server.private_ip
  description = "Private IP of the Strapi EC2 instance"
}

output "erp_private_ip" {
  value       = module.erp_server.private_ip
  description = "Private IP of the ERP EC2 instance"
}

output "cloudfront_domain_name" {
  value       = module.cdn.cloudfront_domain_name
  description = "Domain name of the CloudFront CDN"
}
