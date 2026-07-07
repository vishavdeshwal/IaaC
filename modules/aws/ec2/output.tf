output "instance_id" {
  value       = aws_instance.ec2.id
  description = "ID of the EC2 instance"
}

output "instance_arn" {
  value       = aws_instance.ec2.arn
  description = "ARN of the EC2 instance"
}

output "private_ip" {
  value       = aws_instance.ec2.private_ip
  description = "Private IP address of the instance"
}

output "public_ip" {
  value       = aws_instance.ec2.public_ip
  description = "Public IP address of the instance (null if no public IP assigned)"
}

output "private_dns" {
  value       = aws_instance.ec2.private_dns
  description = "Private DNS hostname of the instance"
}
