output "asg_id" {
    value       = aws_autoscaling_group.asg.id
    description = "ID of the Auto Scaling Group"
}

output "asg_arn" {
    value       = aws_autoscaling_group.asg.arn
    description = "ARN of the Auto Scaling Group"
}

output "asg_name" {
    value       = aws_autoscaling_group.asg.name
    description = "Name of the Auto Scaling Group"
}

output "launch_template_id" {
    value       = aws_launch_template.asg.id
    description = "ID of the Launch Template"
}

output "launch_template_arn" {
    value       = aws_launch_template.asg.arn
    description = "ARN of the Launch Template"
}

output "launch_template_latest_version" {
    value       = aws_launch_template.asg.latest_version
    description = "Latest version number of the Launch Template"
}
