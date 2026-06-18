output "app_id" {
  value       = aws_amplify_app.app.id
  description = "Amplify App ID"
}

output "app_arn" {
  value       = aws_amplify_app.app.arn
  description = "Amplify App ARN"
}

output "app_name" {
  value       = aws_amplify_app.app.name
  description = "Amplify App name"
}

output "default_domain" {
  value       = aws_amplify_app.app.default_domain
  description = "Default Amplify domain (*.amplifyapp.com)"
}

output "branch_ids" {
  value       = { for k, v in aws_amplify_branch.branches : k => v.id }
  description = "Map of branch_name => branch resource ID"
}

output "domain_association_id" {
  value       = length(aws_amplify_domain_association.domain) > 0 ? aws_amplify_domain_association.domain[0].id : null
  description = "Domain association ID (null if no custom domain)"
}
