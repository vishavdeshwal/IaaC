output "function_arn" {
    value       = aws_lambda_function.lambda.arn
    description = "ARN of the Lambda function"
}

output "function_name" {
    value       = aws_lambda_function.lambda.function_name
    description = "Name of the Lambda function"
}

output "invoke_arn" {
    value       = aws_lambda_function.lambda.invoke_arn
    description = "ARN to be used for invoking the function from API Gateway"
}

output "qualified_arn" {
    value       = aws_lambda_function.lambda.qualified_arn
    description = "ARN including the function version"
}

output "role_arn" {
    value       = aws_iam_role.lambda.arn
    description = "ARN of the Lambda IAM execution role"
}

output "role_name" {
    value       = aws_iam_role.lambda.name
    description = "Name of the Lambda IAM execution role"
}
