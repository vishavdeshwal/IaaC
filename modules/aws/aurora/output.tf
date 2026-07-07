output "cluster_id" {
  value       = aws_rds_cluster.aurora.id
  description = "ID of the Aurora cluster"
}

output "cluster_arn" {
  value       = aws_rds_cluster.aurora.arn
  description = "ARN of the Aurora cluster"
}

output "cluster_endpoint" {
  value       = aws_rds_cluster.aurora.endpoint
  description = "Writer endpoint of the Aurora cluster"
}

output "reader_endpoint" {
  value       = aws_rds_cluster.aurora.reader_endpoint
  description = "Reader endpoint of the Aurora cluster"
}

output "cluster_port" {
  value       = aws_rds_cluster.aurora.port
  description = "Port the Aurora cluster is listening on"
}

output "database_name" {
  value       = aws_rds_cluster.aurora.database_name
  description = "Name of the default database"
}

output "master_username" {
  value       = aws_rds_cluster.aurora.master_username
  sensitive   = true
  description = "Master username"
}

output "subnet_group_name" {
  value       = aws_db_subnet_group.aurora.name
  description = "Name of the Aurora DB subnet group"
}
