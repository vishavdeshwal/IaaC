variable "cluster_id" {
  type        = string
  description = "ID of the ECS cluster"
}

variable "service_name" {
  type        = string
  description = "Name of the ECS service"
}

variable "task_family" {
  type        = string
  description = "Family name for the task definition"
}

variable "cpu" {
  type        = number
  default     = 256
  description = "Task CPU units (256, 512, 1024, 2048, 4096)"
}

variable "memory" {
  type        = number
  default     = 512
  description = "Task memory in MiB"
}

variable "container_definitions" {
  type        = string
  description = "JSON-encoded list of container definitions for the task"
}

variable "desired_count" {
  type        = number
  default     = 1
  description = "Desired number of running tasks"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs where tasks will run"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for the ECS tasks"
}

variable "assign_public_ip" {
  type        = bool
  default     = false
  description = "Whether to assign a public IP to Fargate tasks"
}

# Load Balancer integration (optional)
variable "target_group_arn" {
  type        = string
  default     = null
  description = "ARN of the target group to register tasks with. If null, no load balancer is attached."
}

variable "container_name" {
  type        = string
  default     = null
  description = "Container name to register with the load balancer. Required if target_group_arn is set."
}

variable "container_port" {
  type        = number
  default     = null
  description = "Container port to register with the load balancer. Required if target_group_arn is set."
}

# Container Insights
variable "enable_container_insights" {
  type        = bool
  default     = false
  description = "Whether to enable CloudWatch Container Insights on the cluster"
}

variable "health_check_grace_period_seconds" {
  type        = number
  default     = null
  description = "Seconds to ignore ELB health checks after a task starts. Only valid when target_group_arn is set. Prevents the scheduler from killing slow-booting tasks before they can serve /health."
}

variable "enable_deployment_circuit_breaker" {
  type        = bool
  default     = true
  description = "Abort and roll back a deployment that never reaches a steady state, instead of looping failed tasks indefinitely."
}

variable "environment" {
  type = string
}

variable "project" {
  type = string
}
