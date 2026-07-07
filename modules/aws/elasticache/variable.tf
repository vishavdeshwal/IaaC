variable "name" {
  type        = string
  description = "Base name for the ElastiCache cluster/replication group"
}

variable "engine" {
  type        = string
  default     = "redis"
  description = "Cache engine: 'redis' or 'memcached'"
}

variable "engine_version" {
  type        = string
  default     = null
  description = "Engine version (e.g. '7.1' for Redis, '1.6.17' for Memcached). If null, AWS picks the default."
}

variable "node_type" {
  type        = string
  default     = "cache.t3.micro"
  description = "ElastiCache node type"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the ElastiCache subnet group"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs to associate with the cluster"
}

# --- Memcached-specific ---

variable "num_cache_nodes" {
  type        = number
  default     = 1
  description = "Number of cache nodes. For Memcached: 1-40. For Redis without cluster mode, use num_cache_clusters."
}

# --- Redis-specific ---

variable "num_cache_clusters" {
  type        = number
  default     = 1
  description = "For Redis: total number of clusters (1 = single node, 2+ = primary + replicas)"
}

variable "cluster_mode_enabled" {
  type        = bool
  default     = false
  description = "Whether to enable Redis cluster mode (sharding). Only applies to engine = 'redis'."
}

variable "num_node_groups" {
  type        = number
  default     = 1
  description = "Number of shards (node groups) for Redis cluster mode"
}

variable "replicas_per_node_group" {
  type        = number
  default     = 1
  description = "Number of replicas per shard in Redis cluster mode"
}

# --- Security ---

variable "at_rest_encryption" {
  type        = bool
  default     = true
  description = "Whether to enable encryption at rest. Only for Redis."
}

variable "transit_encryption" {
  type        = bool
  default     = true
  description = "Whether to enable in-transit encryption (TLS). Only for Redis."
}

variable "auth_token" {
  type        = string
  default     = null
  sensitive   = true
  description = "Redis AUTH token (password). Only used when transit_encryption = true."
}

# --- Maintenance ---

variable "maintenance_window" {
  type        = string
  default     = "sun:05:00-sun:06:00"
  description = "Weekly maintenance window"
}

variable "snapshot_retention_limit" {
  type        = number
  default     = 1
  description = "Number of days to retain Redis snapshots. 0 = disabled."
}

variable "snapshot_window" {
  type        = string
  default     = "03:00-04:00"
  description = "Daily time range for Redis snapshots"
}

variable "apply_immediately" {
  type        = bool
  default     = false
  description = "Whether to apply changes immediately"
}

variable "automatic_failover_enabled" {
  type        = bool
  default     = false
  description = "Enable automatic failover for Redis replication groups. Requires num_cache_clusters >= 2 or cluster_mode_enabled."
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "name_override" {
  type    = string
  default = null
}

variable "subnet_group_name_override" {
  type    = string
  default = null
}

