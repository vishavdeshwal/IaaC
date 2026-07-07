output "cluster_id" {
  value       = aws_ecs_cluster.ec2.id
  description = "ID of the ECS cluster"
}

output "cluster_arn" {
  value       = aws_ecs_cluster.ec2.arn
  description = "ARN of the ECS cluster"
}

output "cluster_name" {
  value       = aws_ecs_cluster.ec2.name
  description = "Name of the ECS cluster"
}

output "service_id" {
  value       = aws_ecs_service.ec2.id
  description = "ID of the ECS service"
}

output "service_name" {
  value       = aws_ecs_service.ec2.name
  description = "Name of the ECS service"
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.ec2.arn
  description = "ARN of the ECS task definition"
}

output "task_definition_family" {
  value       = aws_ecs_task_definition.ec2.family
  description = "Family of the ECS task definition"
}

output "execution_role_arn" {
  value       = aws_iam_role.execution.arn
  description = "ARN of the task execution IAM role"
}

output "task_role_arn" {
  value       = aws_iam_role.task.arn
  description = "ARN of the task IAM role"
}

output "instance_profile_arn" {
  value       = aws_iam_instance_profile.instance.arn
  description = "ARN of the EC2 instance profile — attach this to your ASG instances so they can join the ECS cluster"
}

output "instance_profile_name" {
  value       = aws_iam_instance_profile.instance.name
  description = "Name of the EC2 instance profile"
}
