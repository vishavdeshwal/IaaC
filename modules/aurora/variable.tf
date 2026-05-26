variable "cluster_identifier" {
  type        = string
  description = "Unique identifier for the Aurora cluster"
}

variable "engine" {
  type        = string
  default     = "aurora-mysql"
  description = "Aurora engine: 'aurora-mysql' or 'aurora-postgresql'"
}

variable "engine_version" {
  type        = string
  default     = null
  description = "Engine version (e.g. '8.0.mysql_aurora.3.04.0'). If null, AWS picks the default."
}


variable "serverlessv2_min_capacity" {
    type = number
    default = 0.5
    description = "Minimum Aurora Capacity Units (ACUs) for Serverless v2"
}

variable "serverlessv2_max_capacity" {
    type = number
    default = 1
    description = "Maximum Aurora Capacity Units (ACUs) for Serverless v2"
}

variable "instance_class" {
  type        = string
  default     = "db.t3.medium"
  description = "Instance class for Aurora cluster instances"
}

variable "num_instances" {
  type        = number
  default     = 1
  description = "Number of Aurora cluster instances (writer + readers)"
}

variable "database_name" {
  type        = string
  default     = null
  description = "Name of the default database. Optional."
}

variable "master_username" {
  type        = string
  description = "Master username for the cluster"
}

variable "master_password" {
  type        = string
  sensitive   = true
  description = "Master password for the cluster"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the DB subnet group (should be private subnets)"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs to associate with the cluster"
}

variable "backup_retention_period" {
  type        = number
  default     = 7
  description = "Days to retain automated backups (1–35)"
}

variable "preferred_backup_window" {
  type        = string
  default     = "02:00-03:00"
  description = "Daily time range for automated backups (UTC)"
}

variable "skip_final_snapshot" {
  type        = bool
  default     = true
  description = "Whether to skip final snapshot on deletion. Set false in production."
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Whether to enable deletion protection on the cluster"
}

variable "storage_encrypted" {
  type        = bool
  default     = true
  description = "Whether to encrypt cluster storage at rest"
}

variable "apply_immediately" {
  type        = bool
  default     = false
  description = "Whether to apply changes immediately or during the next maintenance window"
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

