variable "cluster_identifier" {
  type        = string
  description = "The cluster identifier"
}

variable "master_username" {
  type        = string
  description = "The master username for DocumentDB"
}

variable "master_password" {
  type        = string
  description = "The master password for DocumentDB"
  sensitive   = true
}

variable "instance_class" {
  type        = string
  default     = "db.t3.medium"
  description = "The instance class for DocumentDB"
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "Number of instances in the cluster"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the DB subnet group"
}

variable "vpc_security_group_ids" {
  type        = list(string)
  description = "List of security group IDs for the cluster"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "project" {
  type        = string
  description = "Project name"
}
