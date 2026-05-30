output "secret_arn" {
  value       = aws_secretsmanager_secret.secret.arn
  description = "The ARN of the secret"
}

output "secret_id" {
  value       = aws_secretsmanager_secret.secret.id
  description = "The ID of the secret"
}

output "secret_name" {
  value       = aws_secretsmanager_secret.secret.name
  description = "The name of the secret"
}
