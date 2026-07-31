
output "service_id" {
  value       = aws_ecs_service.fargate.id
  description = "ID of the ECS service"
}

output "service_name" {
  value       = aws_ecs_service.fargate.name
  description = "Name of the ECS service"
}

output "task_definition_arn" {
  value       = aws_ecs_task_definition.fargate.arn
  description = "ARN of the ECS task definition"
}

output "task_definition_family" {
  value       = aws_ecs_task_definition.fargate.family
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
