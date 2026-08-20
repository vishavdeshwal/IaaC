output "service_name" {
  value       = aws_ecs_service.service.name
  description = "Name of the ECS service"
}

output "service_arn" {
  value       = aws_ecs_service.service.id
  description = "ARN of the ECS service"
}
