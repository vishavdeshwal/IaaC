output "target_group_arn" {
    value       = aws_lb_target_group.tg.arn
    description = "ARN of the target group — pass this to alb module or ecs/asg modules"
}

output "target_group_id" {
    value       = aws_lb_target_group.tg.id
    description = "ID of the target group"
}

output "target_group_name" {
    value       = aws_lb_target_group.tg.name
    description = "Name of the target group"
}

output "target_group_arn_suffix" {
    value       = aws_lb_target_group.tg.arn_suffix
    description = "ARN suffix for use in CloudWatch metrics"
}
