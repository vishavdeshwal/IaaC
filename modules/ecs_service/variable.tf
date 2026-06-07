variable "service_name" {
  type        = string
  description = "The name of the ECS service"
}

variable "family" {
  type        = string
  description = "The task definition family name"
}

variable "cluster_arn" {
  type        = string
  description = "The ARN of the ECS cluster to deploy into"
}

variable "cpu" {
  type        = string
  default     = "256"
  description = "CPU units for task definition"
}

variable "memory" {
  type        = string
  default     = "512"
  description = "Memory units for task definition"
}

variable "execution_role_arn" {
  type        = string
  description = "The ARN of the ECS task execution role"
}

variable "task_role_arn" {
  type        = string
  description = "The ARN of the ECS task runtime role"
}

variable "container_definitions" {
  type        = string
  description = "A JSON string defining all containers inside the task"
}

variable "desired_count" {
  type        = number
  default     = 1
  description = "Number of active task replicas"
}

variable "platform_version" {
  type        = string
  default     = "LATEST"
  description = "Fargate platform version"
}

variable "availability_zone_rebalancing" {
  type        = string
  default     = "ENABLED"
}

variable "enable_ecs_managed_tags" {
  type    = bool
  default = true
}

variable "enable_execute_command" {
  type    = bool
  default = false
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnets for ECS network configuration"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security groups for ECS network configuration"
}

variable "assign_public_ip" {
  type    = bool
  default = false
}

variable "target_group_arn" {
  type    = string
  default = null
}

variable "container_name" {
  type    = string
  default = null
}

variable "container_port" {
  type    = number
  default = null
}

variable "enable_circuit_breaker" {
  type    = bool
  default = true
}

variable "capacity_providers" {
  type    = list(any)
  default = []
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "requires_compatibilities" {
  type        = list(string)
  default     = ["FARGATE"]
  description = "A set of launch types required by the task"
}

variable "launch_type" {
  type        = string
  default     = null
  description = "The launch type on which to run your service (FARGATE, EC2, or EXTERNAL). If using capacity provider strategies, leave as null."
}

variable "task_definition_arn_override" {
  type        = string
  default     = null
  description = "If provided, bypasses creating a task definition and uses this active ARN/family:revision instead"
}

variable "health_check_grace_period_seconds" {
  type        = number
  default     = 0
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks"
}

