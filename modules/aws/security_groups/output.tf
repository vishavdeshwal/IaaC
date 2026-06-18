output "security_group_id" {
    value = aws_security_group.security_group.id
    description = "ID of the Security group"
}

output "security_group_arn" {
    value = aws_security_group.security_group.arn
    description = "ARN of the Security group"
}

output "security_group_name" {
    value = aws_security_group.security_group.name
    description = "Name of the Security group"
}