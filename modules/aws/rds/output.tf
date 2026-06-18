output "instance_id" {
    value       = aws_db_instance.rds.id
    description = "ID of the RDS instance"
}

output "instance_arn" {
    value       = aws_db_instance.rds.arn
    description = "ARN of the RDS instance"
}

output "endpoint" {
    value       = aws_db_instance.rds.endpoint
    description = "Connection endpoint (host:port)"
}

output "address" {
    value       = aws_db_instance.rds.address
    description = "Hostname of the RDS instance"
}

output "port" {
    value       = aws_db_instance.rds.port
    description = "Port the RDS instance is listening on"
}

output "db_name" {
    value       = aws_db_instance.rds.db_name
    description = "Name of the default database"
}

output "username" {
    value       = aws_db_instance.rds.username
    sensitive   = true
    description = "Master username"
}

output "subnet_group_name" {
    value       = aws_db_subnet_group.rds.name
    description = "Name of the RDS DB subnet group"
}
