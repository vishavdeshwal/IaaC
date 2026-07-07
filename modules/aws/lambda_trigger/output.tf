output "sqs_event_source_mapping_id" {
  value       = length(aws_lambda_event_source_mapping.sqs) > 0 ? aws_lambda_event_source_mapping.sqs[0].id : null
  description = "ID of the SQS event source mapping (null if not enabled)"
}

output "schedule_rule_arn" {
  value       = length(aws_cloudwatch_event_rule.schedule) > 0 ? aws_cloudwatch_event_rule.schedule[0].arn : null
  description = "ARN of the EventBridge schedule rule (null if not enabled)"
}

output "schedule_rule_name" {
  value       = length(aws_cloudwatch_event_rule.schedule) > 0 ? aws_cloudwatch_event_rule.schedule[0].name : null
  description = "Name of the EventBridge schedule rule (null if not enabled)"
}
