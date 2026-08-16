# -------
# Subnet Group (shared by both Redis and Memcached)
# -------

resource "aws_elasticache_subnet_group" "elasticache" {
  name        = var.subnet_group_name_override != null ? var.subnet_group_name_override : lower("${var.environment}-${var.project}-${var.name}-subnet-group")
  subnet_ids  = var.subnet_ids
  description = "ElastiCache subnet group for ${var.name}"

  tags = {
    Name        = "${var.environment}-${var.project}-${var.name}-subnet-group"
    Environment = var.environment
    Project     = var.project
  }
}


# -------
# Redis — Replication Group (standard and cluster mode)
# Created when engine = "redis"
# -------

resource "aws_elasticache_replication_group" "redis" {
  count = var.engine == "redis" || var.engine == "valkey" ? 1 : 0

  replication_group_id = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}"
  description          = "${var.environment}-${var.project} Redis cache"

  engine             = var.engine
  engine_version     = var.engine_version
  node_type          = var.node_type
  subnet_group_name  = aws_elasticache_subnet_group.elasticache.name
  security_group_ids = var.security_group_ids

  at_rest_encryption_enabled = var.at_rest_encryption
  transit_encryption_enabled = var.transit_encryption
  transit_encryption_mode    = var.transit_encryption_mode
  auth_token                 = var.transit_encryption ? var.auth_token : null

  maintenance_window         = var.maintenance_window
  snapshot_retention_limit   = var.snapshot_retention_limit
  snapshot_window            = var.snapshot_window
  apply_immediately          = var.apply_immediately
  automatic_failover_enabled = var.automatic_failover_enabled || var.cluster_mode_enabled

  # Cluster mode configuration (standard Redis vs sharded Cluster Mode)
  num_cache_clusters      = var.cluster_mode_enabled ? null : var.num_cache_clusters
  num_node_groups         = var.cluster_mode_enabled ? var.num_node_groups : null
  replicas_per_node_group = var.cluster_mode_enabled ? var.replicas_per_node_group : null

  tags = {
    Name        = "${var.environment}-${var.project}-${var.name}"
    Environment = var.environment
    Project     = var.project
  }
}


# -------
# Memcached Cluster
# Created when engine = "memcached"
# -------

resource "aws_elasticache_cluster" "memcached" {
  count = var.engine == "memcached" ? 1 : 0

  cluster_id         = var.name_override != null ? var.name_override : "${var.environment}-${var.project}-${var.name}"
  engine             = "memcached"
  engine_version     = var.engine_version
  node_type          = var.node_type
  num_cache_nodes    = var.num_cache_nodes
  subnet_group_name  = aws_elasticache_subnet_group.elasticache.name
  security_group_ids = var.security_group_ids
  maintenance_window = var.maintenance_window
  apply_immediately  = var.apply_immediately

  tags = {
    Name        = "${var.environment}-${var.project}-${var.name}"
    Environment = var.environment
    Project     = var.project
  }
}
