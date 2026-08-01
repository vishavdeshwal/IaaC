output "task_role_name" {
  value       = aws_iam_role.task.name
  description = "Name of the task IAM role"
}

output "execution_role_name" {
  value       = aws_iam_role.execution.name
  description = "Name of the execution IAM role"
}
