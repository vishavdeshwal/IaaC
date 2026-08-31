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

output "app_public_ip" {
  description = "The public Elastic IP address of the Standalone Application EC2 Instance"
  value       = aws_eip.app.public_ip
}

output "app_private_ip" {
  description = "The private IP address of the Standalone Application EC2 Instance"
  value       = module.app_server.private_ip
}
