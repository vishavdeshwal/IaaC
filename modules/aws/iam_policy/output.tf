output "policy_arn" {
  value       = var.is_inline ? null : aws_iam_policy.policy[0].arn
  description = "The ARN of the managed policy"
}

output "policy_name" {
  value       = var.is_inline ? aws_iam_role_policy.inline_policy[0].name : aws_iam_policy.policy[0].name
  description = "The name of the policy"
}

output "policy_id" {
  value       = var.is_inline ? aws_iam_role_policy.inline_policy[0].id : aws_iam_policy.policy[0].id
  description = "The ID of the policy"
}
