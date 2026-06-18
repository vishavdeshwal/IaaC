variable "cluster_name" {
    type        = string
    description = "Name of the ECS cluster"
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
    default     = null
    description = "Task CPU units. Optional for EC2 launch type."
}

variable "memory" {
    type        = number
    default     = 512
    description = "Task memory in MiB"
}

variable "container_definitions" {
    type        = string
    description = "JSON-encoded list of container definitions"
}

variable "desired_count" {
    type        = number
    default     = 1
    description = "Desired number of running tasks"
}

variable "security_group_ids" {
    type        = list(string)
    description = "Security group IDs for ECS tasks"
}

variable "subnet_ids" {
    type        = list(string)
    description = "Subnet IDs for the ECS tasks"
}

# Load Balancer integration (optional)
variable "target_group_arn" {
    type        = string
    default     = null
    description = "ARN of the target group. If null, no load balancer is attached."
}

variable "container_name" {
    type        = string
    default     = null
    description = "Container name to register with the load balancer"
}

variable "container_port" {
    type        = number
    default     = null
    description = "Container port to register with the load balancer"
}

variable "enable_container_insights" {
    type        = bool
    default     = false
    description = "Enable CloudWatch Container Insights on the cluster"
}

variable "environment" {
    type = string
}

variable "project" {
    type = string
}
