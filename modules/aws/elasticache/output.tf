output "subnet_group_name" {
    value       = aws_elasticache_subnet_group.elasticache.name
    description = "Name of the ElastiCache subnet group"
}

# ---- Redis Outputs ----

output "redis_id" {
    value       = length(aws_elasticache_replication_group.redis) > 0 ? aws_elasticache_replication_group.redis[0].id : null
    description = "ID of the Redis replication group (null if engine is memcached)"
}

output "redis_arn" {
    value       = length(aws_elasticache_replication_group.redis) > 0 ? aws_elasticache_replication_group.redis[0].arn : null
    description = "ARN of the Redis replication group (null if engine is memcached)"
}

output "redis_primary_endpoint" {
    value       = length(aws_elasticache_replication_group.redis) > 0 ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : null
    description = "Primary endpoint for Redis (use for writes). Null if cluster mode or memcached."
}

output "redis_reader_endpoint" {
    value       = length(aws_elasticache_replication_group.redis) > 0 ? aws_elasticache_replication_group.redis[0].reader_endpoint_address : null
    description = "Reader endpoint for Redis replicas (use for reads). Null if single node or memcached."
}

output "redis_configuration_endpoint" {
    value       = length(aws_elasticache_replication_group.redis) > 0 ? aws_elasticache_replication_group.redis[0].configuration_endpoint_address : null
    description = "Configuration endpoint for Redis cluster mode (null if cluster mode is disabled or memcached)"
}

output "redis_port" {
    value       = length(aws_elasticache_replication_group.redis) > 0 ? aws_elasticache_replication_group.redis[0].port : null
    description = "Port for the Redis cluster (default 6379)"
}

# ---- Memcached Outputs ----

output "memcached_id" {
    value       = length(aws_elasticache_cluster.memcached) > 0 ? aws_elasticache_cluster.memcached[0].id : null
    description = "ID of the Memcached cluster (null if engine is redis)"
}

output "memcached_configuration_endpoint" {
    value       = length(aws_elasticache_cluster.memcached) > 0 ? aws_elasticache_cluster.memcached[0].configuration_endpoint : null
    description = "Configuration endpoint for Memcached (null if engine is redis)"
}

output "memcached_port" {
    value       = length(aws_elasticache_cluster.memcached) > 0 ? aws_elasticache_cluster.memcached[0].port : null
    description = "Port for the Memcached cluster (default 11211)"
}
