variable "name" {
    type        = string
    description = "Name for the ALB"
}

variable "internal" {
    type        = bool
    default     = false
    description = "Whether the ALB is internal (private) or internet-facing"
}

variable "security_group_ids" {
    type        = list(string)
    description = "Security group IDs to attach to the ALB"
}

variable "subnet_ids" {
    type        = list(string)
    description = "Public (internet-facing) or private (internal) subnet IDs for the ALB"
}

variable "enable_deletion_protection" {
    type        = bool
    default     = false
    description = "Whether to enable deletion protection. Set true in production."
}

variable "idle_timeout" {
    type        = number
    default     = 60
    description = "Idle connection timeout in seconds"
}

variable "enable_http2" {
    type        = bool
    default     = true
    description = "Whether to enable HTTP/2"
}

# --- HTTP Listener ---

variable "http_port" {
    type        = number
    default     = 80
    description = "Port for the HTTP listener"
}

variable "http_protocol" {
    type        = string
    default     = "HTTP"
    description = "Protocol for the HTTP listener ('HTTP' or 'HTTPS')"
}

variable "http_certificate_arn" {
    type        = string
    default     = null
    description = "ACM certificate ARN for the HTTP listener if protocol is HTTPS"
}

variable "http_default_action" {
    type        = string
    default     = "redirect_to_https"
    description = "Default action for HTTP: 'redirect_to_https' or 'forward'. Use 'forward' if no HTTPS."
}

variable "http_target_group_arn" {
    type        = string
    default     = null
    description = "Target group ARN for HTTP forward action. Required if http_default_action = 'forward'."
}

# --- HTTPS Listener ---

variable "https_port" {
    type        = number
    default     = 443
    description = "Port for the HTTPS listener"
}

variable "certificate_arn" {
    type        = string
    default     = null
    description = "ACM certificate ARN for HTTPS. If null, no HTTPS listener is created."
}

variable "https_target_group_arn" {
    type        = string
    default     = null
    description = "Target group ARN for HTTPS forward action"
}

variable "ssl_policy" {
    type        = string
    default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    description = "SSL security policy for HTTPS listener"
}

variable "access_logs_bucket" {
    type        = string
    default     = null
    description = "S3 bucket name for ALB access logs. If null, access logs are disabled."
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

