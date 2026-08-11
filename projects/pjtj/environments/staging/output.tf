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
  description = "The ID of the EC2 instance"
}

output "ec2_public_eip" {
  value       = module.ec2_eip.public_ip
  description = "The Elastic IP attached to the EC2 instance"
}

output "ec2_private_ip" {
  value       = module.ec2.private_ip
  description = "The private IP address of the EC2 instance"
}
