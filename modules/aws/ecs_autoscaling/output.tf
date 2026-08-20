output "target_arn" {
  value       = aws_appautoscaling_target.ecs.arn
  description = "ARN of the Application Auto Scaling target"
}
