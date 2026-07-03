output "endpoint" {
  description = "The DNS address of the DocumentDB instance"
  value       = aws_docdb_cluster.cluster.endpoint
}

output "port" {
  description = "The port on which the DB accepts connections"
  value       = aws_docdb_cluster.cluster.port
}

output "cluster_arn" {
  description = "The ARN of the DocumentDB cluster"
  value       = aws_docdb_cluster.cluster.arn
}
