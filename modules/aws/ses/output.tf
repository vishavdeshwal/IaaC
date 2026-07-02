output "arn" {
  value       = aws_ses_email_identity.email.arn
  description = "The ARN of the SES email identity"
}
