output "table_arn" {
  value       = aws_dynamodb_table.table.arn
  description = "The ARN of the DynamoDB table"
}

output "table_id" {
  value       = aws_dynamodb_table.table.id
  description = "The ID/name of the DynamoDB table"
}

output "table_stream_arn" {
  value       = aws_dynamodb_table.table.stream_arn
  description = "The ARN of the Table Stream, if enabled"
}
