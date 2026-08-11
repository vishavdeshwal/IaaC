output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the VPC"
}

output "public_subnet_ids" {
  value       = module.subnets.public_subnet_ids
  description = "Public subnet IDs"
}

output "private_subnet_ids" {
  value       = module.subnets.private_subnet_ids
  description = "Private subnet IDs"
}

output "ec2_instance_id" {
  value       = module.ec2.instance_id
  description = "The ID of the EC2 ERP server instance"
}

output "ec2_public_eip" {
  value       = module.ec2_eip.public_ip
  description = "The Elastic IP attached to the EC2 ERP server"
}

output "ec2_private_ip" {
  value       = module.ec2.private_ip
  description = "The private IP address of the EC2 ERP server"
}

output "mariadb_endpoint" {
  value       = module.rds_mariadb.endpoint
  description = "The connection endpoint for MariaDB"
}

output "redis_primary_endpoint" {
  value       = module.redis.redis_primary_endpoint
  description = "The primary endpoint address for ElastiCache Redis"
}
