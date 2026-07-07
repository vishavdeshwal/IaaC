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
