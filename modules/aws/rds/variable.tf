variable "identifier" {
  type        = string
  description = "Unique identifier for the RDS instance"
}

variable "engine" {
  type        = string
  default     = "mysql"
  description = "Database engine: 'mysql' or 'postgres'"
}

variable "engine_version" {
  type        = string
  default     = null
  description = "Engine version (e.g. '8.0', '15.3'). If null, AWS picks the default."
}

variable "instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "RDS instance class"
}

variable "allocated_storage" {
  type        = number
  default     = 20
  description = "Allocated storage in GiB"
}

variable "max_allocated_storage" {
  type        = number
  default     = null
  description = "Upper limit for storage autoscaling in GiB. If null, autoscaling is disabled."
}

variable "db_name" {
  type        = string
  default     = null
  description = "Name of the database to create. Optional."
}

variable "username" {
  type        = string
  description = "Master username"
}

variable "password" {
  type        = string
  sensitive   = true
  description = "Master password"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the DB subnet group"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs to attach to the RDS instance"
}

variable "subnet_group_name_override" {
  type        = string
  default     = null
  description = "Optional override for DB subnet group name"
}

variable "multi_az" {
  type        = bool
  default     = false
  description = "Whether to enable Multi-AZ deployment"
}

variable "publicly_accessible" {
  type        = bool
  default     = false
  description = "Whether the instance should be publicly accessible"
}

variable "backup_retention_period" {
  type        = number
  default     = 7
  description = "Days to retain automated backups (0–35). 0 disables backups."
}

variable "backup_window" {
  type        = string
  default     = "02:00-03:00"
  description = "Daily time range for automated backups (UTC)"
}

variable "maintenance_window" {
  type        = string
  default     = "Mon:04:00-Mon:05:00"
  description = "Weekly time range for maintenance"
}

variable "skip_final_snapshot" {
  type        = bool
  default     = true
  description = "Whether to skip final snapshot on deletion. Set false in production."
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Whether to enable deletion protection"
}

variable "storage_encrypted" {
  type        = bool
  default     = true
  description = "Whether to encrypt storage at rest"
}

variable "apply_immediately" {
  type        = bool
  default     = false
  description = "Apply changes immediately or during next maintenance window"
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "parameter_group_name" {
  type        = string
  default     = null
  description = "Name of the DB parameter group to associate"
}

variable "ca_cert_identifier" {
  type        = string
  default     = null
  description = "Identifier of the CA certificate for the DB instance"
}

variable "allow_major_version_upgrade" {
  type        = bool
  default     = false
  description = "Indicates that major version upgrades are allowed"
}

variable "auto_minor_version_upgrade" {
  type        = bool
  default     = null
  description = "Indicates that minor engine upgrades will be applied automatically"
}

variable "final_snapshot_identifier" {
  type        = string
  default     = null
  description = "Name of final snapshot when instance is deleted"
}

variable "copy_tags_to_snapshot" {
  type        = bool
  default     = true
  description = "Copy all Instance tags to snapshots"
}

variable "storage_type" {
  type        = string
  default     = null
  description = "One of 'standard', 'gp2', 'gp3', 'io1', 'io2'"
}

variable "iops" {
  type        = number
  default     = null
  description = "The amount of provisioned IOPS"
}

variable "storage_throughput" {
  type        = number
  default     = null
  description = "Storage throughput value for gp3"
}

variable "kms_key_id" {
  type        = string
  default     = null
  description = "ARN for the KMS key which encrypts storage"
}

variable "manage_master_user_password" {
  type        = bool
  default     = false
  description = "Set to true to allow RDS to manage the master user password in Secrets Manager"
}

variable "master_user_secret_kms_key_id" {
  type        = string
  default     = null
  description = "Amazon KMS Key ID to encrypt the secret"
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  default     = []
  description = "List of log types to export to CloudWatch"
}

variable "monitoring_interval" {
  type        = number
  default     = 0
  description = "Interval, in seconds, between points when Enhanced Monitoring metrics are collected"
}

variable "monitoring_role_arn" {
  type        = string
  default     = null
  description = "ARN for the IAM role that permits RDS to send Enhanced Monitoring metrics to CloudWatch Logs"
}

variable "performance_insights_enabled" {
  type        = bool
  default     = false
  description = "Specifies whether Performance Insights are enabled"
}

variable "performance_insights_retention_period" {
  type        = number
  default     = 7
  description = "Amount of time in days to retain Performance Insights data"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to add to all resources"
}

variable "identifier_override" {
  type        = string
  default     = null
  description = "Optional DB instance identifier override"
}

