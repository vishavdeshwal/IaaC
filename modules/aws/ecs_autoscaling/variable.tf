variable "name" {
  type        = string
  description = "Name identifier for the autoscaling policy"
}

variable "cluster_name" {
  type        = string
  description = "Name of the ECS cluster"
}

variable "service_name" {
  type        = string
  description = "Name of the ECS service"
}

variable "min_capacity" {
  type        = number
  default     = 1
  description = "Minimum number of task instances"
}

variable "max_capacity" {
  type        = number
  default     = 4
  description = "Maximum number of task instances"
}

variable "enable_cpu_scaling" {
  type        = bool
  default     = true
  description = "Enable CPU target tracking policy"
}

variable "cpu_target_value" {
  type        = number
  default     = 70.0
  description = "Target average CPU utilization percentage"
}

variable "enable_memory_scaling" {
  type        = bool
  default     = false
  description = "Enable Memory target tracking policy"
}

variable "memory_target_value" {
  type        = number
  default     = 75.0
  description = "Target average Memory utilization percentage"
}

variable "alb_arn_suffix" {
  type        = string
  default     = null
  description = "ALB ARN Suffix for request count scaling"
}

variable "target_group_arn_suffix" {
  type        = string
  default     = null
  description = "Target Group ARN Suffix for request count scaling"
}

variable "alb_request_count_target_value" {
  type        = number
  default     = 1000.0
  description = "Target ALB requests per target per minute"
}

variable "scale_in_cooldown" {
  type        = number
  default     = 300
  description = "Scale in cooldown period in seconds"
}

variable "scale_out_cooldown" {
  type        = number
  default     = 60
  description = "Scale out cooldown period in seconds"
}

variable "environment" {
  type        = string
  description = "Target Environment"
}

variable "project" {
  type        = string
  description = "Project Name"
}
