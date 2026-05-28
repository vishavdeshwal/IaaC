output "role_arn" {
  value       = aws_iam_role.role.arn
  description = "The ARN of the created IAM role"
}

output "role_name" {
  value       = aws_iam_role.role.name
  description = "The name of the created IAM role"
}

output "role_id" {
  value       = aws_iam_role.role.id
  description = "The ID of the created IAM role"
}
