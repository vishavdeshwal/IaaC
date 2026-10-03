output "vpc_id" {
  description = "The ID of the staging VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "The map of public subnet IDs"
  value       = module.subnets.public_subnet_ids
}

output "private_subnet_ids" {
  description = "The map of private subnet IDs"
  value       = module.subnets.private_subnet_ids
}

output "nat_gateway_ip" {
  description = "Public IP of the NAT Gateway"
  value       = module.nat_eip.public_ip
}

output "app_server_public_ip" {
  description = "The public Elastic IP address of the Standalone Application Server"
  value       = aws_eip.app.public_ip
}

output "app_server_private_ip" {
  description = "The private IP address of the Standalone Application Server"
  value       = module.app_server.private_ip
}

output "erp_server_public_ip" {
  description = "The public Elastic IP address of the Standalone ERP Server"
  value       = aws_eip.erp.public_ip
}

output "erp_server_private_ip" {
  description = "The private IP address of the Standalone ERP Server"
  value       = module.erp_server.private_ip
}

output "s3_media_bucket_name" {
  description = "Name of the S3 media bucket"
  value       = module.s3_media.bucket_id
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront CDN distribution"
  value       = module.cdn.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront CDN distribution"
  value       = module.cdn.cloudfront_distribution_id
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront CDN distribution"
  value       = module.cdn.cloudfront_distribution_arn
}
