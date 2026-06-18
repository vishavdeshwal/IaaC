output "cluster_arn" {
  value       = aws_ecs_cluster.cluster.arn
  description = "The ARN of the ECS cluster"
}

output "cluster_name" {
  value       = aws_ecs_cluster.cluster.name
  description = "The name of the ECS cluster"
}

output "cluster_id" {
  value       = aws_ecs_cluster.cluster.id
  description = "The ID of the ECS cluster"
}
