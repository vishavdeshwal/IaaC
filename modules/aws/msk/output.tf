output "cluster_arn" {
  value       = aws_msk_cluster.msk.arn
  description = "ARN of the MSK cluster"
}

output "bootstrap_brokers_plaintext" {
  value       = aws_msk_cluster.msk.bootstrap_brokers
  description = "Comma-separated list of plaintext Kafka bootstrap brokers"
}

output "bootstrap_brokers_tls" {
  value       = aws_msk_cluster.msk.bootstrap_brokers_tls
  description = "Comma-separated list of TLS Kafka bootstrap brokers"
}

output "zookeeper_connect_string" {
  value       = aws_msk_cluster.msk.zookeeper_connect_string
  description = "Zookeeper connection string"
}
