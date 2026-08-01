variable "name" {
  type        = string
  description = "Name for the target group"
}

variable "port" {
  type        = number
  description = "Port the targets are listening on"
}

variable "protocol" {
  type        = string
  default     = "HTTP"
  description = "Protocol for routing traffic to targets: HTTP or HTTPS"
}

variable "target_type" {
  type        = string
  default     = "instance"
  description = "Type of target: 'instance', 'ip', or 'lambda'"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the target group is created"
}

# --- Health Check ---

variable "health_check_path" {
  type        = string
  default     = "/"
  description = "URL path for health check requests"
}

variable "health_check_protocol" {
  type        = string
  default     = "HTTP"
  description = "Protocol for health checks"
}

variable "health_check_port" {
  type        = string
  default     = "traffic-port"
  description = "Port for health checks. 'traffic-port' uses the target's traffic port."
}

variable "health_check_interval" {
  type        = number
  default     = 30
  description = "Seconds between health checks"
}

variable "health_check_timeout" {
  type        = number
  default     = 5
  description = "Seconds to wait for a response before marking unhealthy"
}

variable "healthy_threshold" {
  type        = number
  default     = 3
  description = "Consecutive successful checks to mark target as healthy"
}

variable "unhealthy_threshold" {
  type        = number
  default     = 3
  description = "Consecutive failed checks to mark target as unhealthy"
}

variable "health_check_matcher" {
  type        = string
  default     = "200"
  description = "HTTP status codes indicating a successful health check (e.g. '200' or '200-299')"
}

# --- Stickiness ---

variable "stickiness_enabled" {
  type        = bool
  default     = false
  description = "Whether to enable sticky sessions"
}

variable "stickiness_duration" {
  type        = number
  default     = 86400
  description = "Stickiness cookie duration in seconds"
}

variable "deregistration_delay" {
  type        = number
  default     = 300
  description = "Seconds to wait before deregistering a target"
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

variable "use_name_prefix" {
  type        = bool
  default     = false
  description = "If true, omits explicit name to let AWS autogenerate it (useful for recreate replacements)"
}


variable "name_prefix" {
  type        = string
  default     = null
  description = "Max 6 characters. Overrides the default tf- prefix if use_name_prefix is true."
}
