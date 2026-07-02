output "topic_arn" {
  value       = aws_sns_topic.topic.arn
  description = "ARN of the SNS topic"
}

output "topic_name" {
  value       = aws_sns_topic.topic.name
  description = "Name of the SNS topic"
}
